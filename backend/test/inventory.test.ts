import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import EmbeddedPostgres from "../support/local-postgres.js";
import type { Pool } from "pg";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../src/app.js";
import { createPool, migrate } from "../src/database.js";
import { hashPassword, tokenHash } from "../src/security.js";

let pg: EmbeddedPostgres;
let pool: Pool;
let app: FastifyInstance;
let adminToken: string;
let staffToken: string;
let staffId: string;
let databaseDir: string;
const adminPassword = "Admin-test-password-42";
const staffPassword = "Staff-test-password-42";
const authorization = (token: string) => ({ authorization: `Bearer ${token}` });

before(
  async () => {
    databaseDir = await mkdtemp(path.join(tmpdir(), "smartfarm-stock-test-"));
    const port = 55441;
    pg = new EmbeddedPostgres({
      databaseDir,
      port,
      user: "testuser",
      password: "test-only-password",
      persistent: true,
      authMethod: "scram-sha-256",
      postgresFlags: ["-h", "127.0.0.1"],
      initdbFlags: ["--encoding=UTF8", "--locale=C"],
      onLog: () => {},
      onError: (message) =>
        process.stderr.write(
          JSON.stringify({
            level: "WARN",
            component: "test-postgres",
            message: String(message),
          }) + "\n",
        ),
    });
    await pg.initialise();
    await pg.start();
    await pg.createDatabase("smartfarm_test");
    pool = createPool(
      `postgresql://testuser:test-only-password@127.0.0.1:${port}/smartfarm_test`,
    );
    await migrate(pool);
    await migrate(pool);
    await pool.query(
      "INSERT INTO users(email,name,password_hash,role) VALUES($1,$2,$3,'ADMIN')",
      ["admin@test.local", "Admin", await hashPassword(adminPassword)],
    );
    app = await buildApp(
      pool,
      {
        DATABASE_URL: "",
        NODE_ENV: "test",
        HOST: "127.0.0.1",
        PORT: 3000,
        SESSION_HOURS: 8,
        CORS_ORIGINS: "http://localhost:8080",
      },
      false,
    );
    adminToken = (
      await app.inject({
        method: "POST",
        url: "/api/auth/login",
        payload: { email: "admin@test.local", password: adminPassword },
      })
    ).json().token;
    staffId = (
      await app.inject({
        method: "POST",
        url: "/api/users",
        headers: authorization(adminToken),
        payload: {
          name: "Staff",
          email: "staff@test.local",
          password: staffPassword,
        },
      })
    ).json().user.id;
    staffToken = (
      await app.inject({
        method: "POST",
        url: "/api/auth/login",
        payload: { email: "staff@test.local", password: staffPassword },
      })
    ).json().token;
  },
  { timeout: 90000 },
);

after(async () => {
  if (app) await app.close();
  if (pool) await pool.end();
  if (pg) await pg.stop();
  // Only remove the unique directory created by this test; Windows can retain file handles briefly.
  if (databaseDir) {
    const resolved = path.resolve(databaseDir);
    if (
      path.dirname(resolved) !== path.resolve(tmpdir()) ||
      !path.basename(resolved).startsWith("smartfarm-stock-test-")
    )
      throw new Error("Unsafe test cleanup path");
    await rm(resolved, {
      recursive: true,
      force: true,
      maxRetries: 8,
      retryDelay: 300,
    });
  }
});

import { randomUUID } from "node:crypto";
import sharp from "sharp";
import { today } from "../src/farm/routes.js";
let feedId: string, inId: string, outId: string, areaId: string, penId: string;
const now = today();
const send = (
  method: "GET" | "POST" | "PATCH" | "DELETE",
  url: string,
  payload?: object,
  token = adminToken,
) =>
  app.inject({
    method,
    url,
    headers: authorization(token),
    ...(payload ? { payload } : {}),
  });
const entry = (kind: string, quantity: number) => ({
  requestId: randomUUID(),
  feedId,
  kind,
  quantity,
  date: now,
  notes: "",
});
const getStock = async () =>
  (await send("GET", "/api/feeds"))
    .json()
    .feeds.find((f: { id: string }) => f.id === feedId).stock;

test("migration 15 preserves legacy intake and existing manual expenses without inventing costs", async () => {
  const owner = await app.inject({
    method: "POST",
    url: "/api/auth/register",
    payload: {
      name: "Chủ kho cũ",
      farmName: "Trang trại cũ",
      email: "legacy-stock@test.local",
      password: adminPassword,
    },
  });
  assert.equal(owner.statusCode, 201, owner.body);
  const token = owner.json().token;
  const feed = (
    await send(
      "POST",
      "/api/feeds",
      { code: "OLD", name: "Cám cũ", lowStock: 0 },
      token,
    )
  ).json().feed.id;
  const stock = await send(
    "POST",
    "/api/stock-entries",
    { ...entry("IN", 3), feedId: feed },
    token,
  );
  assert.equal(stock.statusCode, 200, stock.body);
  const manualExpense = await send(
    "POST",
    "/api/finance/entries",
    {
      requestId: randomUUID(),
      date: now,
      kind: "OUT",
      category: "FEED",
      amount: 5000,
      content: "Chi đã ghi trước cập nhật",
    },
    token,
  );
  assert.equal(manualExpense.statusCode, 200, manualExpense.body);
  for (const farm of (
    await pool.query<{ schema_name: string }>(
      "SELECT schema_name FROM public.farms",
    )
  ).rows) {
    assert.match(farm.schema_name, /^(public|farm_[a-f0-9]{32})$/);
    await pool.query(
      `ALTER TABLE "${farm.schema_name}".finance_entries DROP COLUMN stock_entry_id`,
    );
  }
  await pool.query("DELETE FROM public.schema_migrations WHERE version=15");
  await migrate(pool);
  await migrate(pool);
  const history = (
    await send("GET", "/api/stock-entries", undefined, token)
  ).json();
  assert.equal(history.entries[0].id, stock.json().entry.id);
  assert.equal(history.entries[0].amount, null);
  const report = (
    await send(
      "GET",
      `/api/finance/report?from=${now}&to=${now}`,
      undefined,
      token,
    )
  ).json();
  assert.equal(report.summary.expense, "5000");
  assert.equal(
    (await send("GET", "/api/finance/entries", undefined, token)).json().total,
    1,
  );
});

test("priced intake creates exactly one linked expense and audit on concurrent retry", async () => {
  const feed = (
    await send("POST", "/api/feeds", {
      code: "COST",
      name: "Cám mua",
      lowStock: 0,
    })
  ).json().feed.id;
  const payload = { ...entry("IN", 20), feedId: feed, amount: 250000 };
  const responses = await Promise.all([
    send("POST", "/api/stock-entries", payload, staffToken),
    send("POST", "/api/stock-entries", payload, staffToken),
  ]);
  for (const response of responses)
    assert.equal(response.statusCode, 200, response.body);
  const stockId = responses[0]!.json().entry.id;
  assert.equal(responses[1]!.json().entry.id, stockId);
  const expenses = await pool.query(
    "SELECT * FROM finance_entries WHERE stock_entry_id=$1",
    [stockId],
  );
  assert.equal(expenses.rowCount, 1);
  const expense = expenses.rows[0];
  assert.equal(expense.kind, "OUT");
  assert.equal(expense.category, "FEED");
  assert.equal(expense.amount, "250000");
  assert.equal(expense.actor_id, staffId);
  assert.equal(
    (
      await pool.query(
        "SELECT count(*)::int AS n FROM finance_audit WHERE entry_id=$1",
        [expense.id],
      )
    ).rows[0].n,
    1,
  );
  const history = (
    await send(
      "GET",
      `/api/stock-entries?feedId=${feed}`,
      undefined,
      staffToken,
    )
  ).json();
  assert.equal(history.entries[0].amount, "250000");
  assert.equal(history.entries[0].financeEntryId, expense.id);
  const ledger = (
    await send(
      "GET",
      `/api/finance/entries?from=${now}&to=${now}&category=FEED`,
    )
  ).json();
  assert.equal(
    ledger.entries.find((e: { id: string }) => e.id === expense.id)
      .stockEntryId,
    stockId,
  );
  const report = (
    await send("GET", `/api/finance/report?from=${now}&to=${now}&category=FEED`)
  ).json();
  assert.equal(report.summary.expense, "250000");
  assert.equal(
    (await send("GET", "/api/finance/entries", undefined, staffToken))
      .statusCode,
    403,
  );
  assert.equal(
    (
      await send(
        "POST",
        "/api/stock-entries",
        { ...payload, amount: 300000 },
        staffToken,
      )
    ).statusCode,
    409,
  );
});

test("purchase amount is a positive integer for intake only; legacy requests remain valid", async () => {
  const feed = (await pool.query("SELECT id FROM feeds WHERE code='COST'"))
    .rows[0].id;
  for (const amount of [0, -1, 1.5, 1000000000001, null, "250000"]) {
    const response = await send("POST", "/api/stock-entries", {
      ...entry("IN", 1),
      feedId: feed,
      amount,
    });
    assert.equal(response.statusCode, 400, response.body);
  }
  assert.equal(
    (
      await send("POST", "/api/stock-entries", {
        ...entry("OUT", 1),
        feedId: feed,
        amount: 1000,
      })
    ).statusCode,
    400,
  );
  const legacy = await send("POST", "/api/stock-entries", {
    ...entry("IN", 1),
    feedId: feed,
  });
  assert.equal(legacy.statusCode, 200, legacy.body);
  assert.equal(
    (
      await pool.query(
        "SELECT count(*)::int AS n FROM finance_entries WHERE stock_entry_id=$1",
        [legacy.json().entry.id],
      )
    ).rows[0].n,
    0,
  );
});

test("stock expense cannot be edited separately; stock and expense cancellation are atomic and idempotent", async () => {
  const feed = (
    await send("POST", "/api/feeds", {
      code: "CANCEL-COST",
      name: "Cám hủy",
      lowStock: 0,
    })
  ).json().feed.id;
  const purchase = await send("POST", "/api/stock-entries", {
    ...entry("IN", 10),
    feedId: feed,
    amount: 100000,
  });
  assert.equal(purchase.statusCode, 200, purchase.body);
  const stockId = purchase.json().entry.id;
  const expense = (
    await pool.query("SELECT * FROM finance_entries WHERE stock_entry_id=$1", [
      stockId,
    ])
  ).rows[0];
  assert.equal(
    (
      await send("PATCH", `/api/finance/entries/${expense.id}`, {
        requestId: randomUUID(),
        reason: "Sửa riêng",
        date: now,
        kind: "OUT",
        category: "FEED",
        amount: 90000,
        content: "Đổi tiền",
      })
    ).statusCode,
    409,
  );
  assert.equal(
    (
      await send("POST", `/api/finance/entries/${expense.id}/cancel`, {
        requestId: randomUUID(),
        reason: "Hủy riêng",
      })
    ).statusCode,
    409,
  );
  const outgoing = await send("POST", "/api/stock-entries", {
    ...entry("OUT", 2),
    feedId: feed,
  });
  const cancel = { requestId: randomUUID(), reason: "Nhập sai cả phiếu" };
  assert.equal(
    (await send("POST", `/api/stock-entries/${stockId}/cancel`, cancel))
      .statusCode,
    409,
  );
  assert.equal(
    (
      await pool.query("SELECT cancelled_at FROM finance_entries WHERE id=$1", [
        expense.id,
      ])
    ).rows[0].cancelled_at,
    null,
  );
  await send("POST", `/api/stock-entries/${outgoing.json().entry.id}/cancel`, {
    requestId: randomUUID(),
    reason: "Hủy xuất",
  });
  assert.equal(
    (await send("POST", `/api/stock-entries/${stockId}/cancel`, cancel))
      .statusCode,
    200,
  );
  assert.equal(
    (await send("POST", `/api/stock-entries/${stockId}/cancel`, cancel))
      .statusCode,
    200,
  );
  assert.ok(
    (
      await pool.query("SELECT cancelled_at FROM stock_entries WHERE id=$1", [
        stockId,
      ])
    ).rows[0].cancelled_at,
  );
  assert.ok(
    (
      await pool.query("SELECT cancelled_at FROM finance_entries WHERE id=$1", [
        expense.id,
      ])
    ).rows[0].cancelled_at,
  );
  const audits = (
    await send("GET", `/api/finance/entries/${expense.id}/history`)
  ).json().history;
  assert.deepEqual(
    audits.map((a: { action: string }) => a.action),
    ["CREATE", "CANCEL"],
  );
  const report = (
    await send("GET", `/api/finance/report?from=${now}&to=${now}&category=FEED`)
  ).json();
  assert.equal(report.summary.expense, "250000");
});

test("failed finance write rolls back inventory and request receipt", async () => {
  const feed = (
    await send("POST", "/api/feeds", {
      code: "FAIL-COST",
      name: "Cám rollback",
      lowStock: 0,
    })
  ).json().feed.id;
  const payload = { ...entry("IN", 5), feedId: feed, amount: 50000 };
  await pool.query(
    `CREATE FUNCTION fail_stock_expense() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'Injected expense failure'; END $$; CREATE TRIGGER fail_stock_expense BEFORE INSERT ON finance_entries FOR EACH ROW WHEN (NEW.stock_entry_id IS NOT NULL) EXECUTE FUNCTION fail_stock_expense()`,
  );
  try {
    assert.equal(
      (await send("POST", "/api/stock-entries", payload)).statusCode,
      500,
    );
    assert.equal(
      (
        await pool.query(
          "SELECT count(*)::int AS n FROM stock_entries WHERE feed_id=$1",
          [feed],
        )
      ).rows[0].n,
      0,
    );
    assert.equal(
      (
        await pool.query(
          "SELECT count(*)::int AS n FROM farm_operations WHERE request_id=$1",
          [payload.requestId],
        )
      ).rows[0].n,
      0,
    );
  } finally {
    await pool.query(
      "DROP TRIGGER fail_stock_expense ON finance_entries; DROP FUNCTION fail_stock_expense()",
    );
  }
  const retried = await send("POST", "/api/stock-entries", payload);
  assert.equal(retried.statusCode, 200, retried.body);
  await pool.query(
    `CREATE FUNCTION fail_stock_cancel() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'Injected cancel failure'; END $$; CREATE TRIGGER fail_stock_cancel BEFORE UPDATE ON finance_entries FOR EACH ROW WHEN (NEW.stock_entry_id IS NOT NULL) EXECUTE FUNCTION fail_stock_cancel()`,
  );
  try {
    assert.equal(
      (
        await send(
          "POST",
          `/api/stock-entries/${retried.json().entry.id}/cancel`,
          { requestId: randomUUID(), reason: "Rollback hủy" },
        )
      ).statusCode,
      500,
    );
    assert.equal(
      (
        await pool.query("SELECT cancelled_at FROM stock_entries WHERE id=$1", [
          retried.json().entry.id,
        ])
      ).rows[0].cancelled_at,
      null,
    );
    assert.equal(
      (
        await pool.query(
          "SELECT cancelled_at FROM finance_entries WHERE stock_entry_id=$1",
          [retried.json().entry.id],
        )
      ).rows[0].cancelled_at,
      null,
    );
  } finally {
    await pool.query(
      "DROP TRIGGER fail_stock_cancel ON finance_entries; DROP FUNCTION fail_stock_cancel()",
    );
  }
});

test("newly registered farm supports purchase expenses in its isolated schema", async () => {
  const registration = await app.inject({
    method: "POST",
    url: "/api/auth/register",
    payload: {
      name: "Chủ kho mới",
      farmName: "Trang trại kho mới",
      email: `stock-${randomUUID()}@test.local`,
      password: adminPassword,
    },
  });
  assert.equal(registration.statusCode, 201, registration.body);
  const token = registration.json().token;
  const feed = (
    await send(
      "POST",
      "/api/feeds",
      { code: "ISOLATED", name: "Cám mới", lowStock: 0 },
      token,
    )
  ).json().feed.id;
  const purchase = await send(
    "POST",
    "/api/stock-entries",
    { ...entry("IN", 1), feedId: feed, amount: 12000 },
    token,
  );
  assert.equal(purchase.statusCode, 200, purchase.body);
  const report = (
    await send(
      "GET",
      `/api/finance/report?from=${now}&to=${now}`,
      undefined,
      token,
    )
  ).json();
  assert.equal(report.summary.expense, "12000");
  assert.equal(
    (
      await send("GET", `/api/stock-entries?feedId=${feed}`, undefined, token)
    ).json().entries[0].amount,
    "12000",
  );
});
test("feed CRUD permissions and input precision", async () => {
  assert.equal(
    (
      await send(
        "POST",
        "/api/feeds",
        { code: "F1", name: "Cám", lowStock: 40 },
        staffToken,
      )
    ).statusCode,
    403,
  );
  assert.equal(
    (
      await send("POST", "/api/feeds", {
        code: "F1",
        name: "Cám",
        lowStock: -1,
      })
    ).statusCode,
    400,
  );
  const r = await send("POST", "/api/feeds", {
    code: "F1",
    name: "Cám",
    lowStock: 40,
    notes: "Demo",
  });
  assert.equal(r.statusCode, 200);
  feedId = r.json().feed.id;
  assert.equal(
    (await send("POST", "/api/feeds", { code: "F1", name: "Cám", lowStock: 0 }))
      .statusCode,
    409,
  );
  assert.equal(
    (await send("POST", "/api/stock-entries", entry("IN", 0))).statusCode,
    400,
  );
  assert.equal(
    (await send("POST", "/api/stock-entries", entry("IN", 0.1234))).statusCode,
    400,
  );
  areaId = (await send("POST", "/api/farm/areas", { name: "Kho A" })).json()
    .item.id;
  penId = (
    await send("POST", "/api/farm/pens", {
      code: "S1",
      name: "Chuồng 1",
      areaId,
      capacity: 5,
    })
  ).json().item.id;
});
test("stock in/out and retry update balance once, with pen and actor history", async () => {
  const input = entry("IN", 100);
  const r = await send("POST", "/api/stock-entries", input, staffToken);
  assert.equal(r.statusCode, 200);
  inId = r.json().entry.id;
  assert.equal(
    (await send("POST", "/api/stock-entries", input, staffToken)).json().entry
      .id,
    inId,
  );
  assert.equal(await getStock(), 100);
  assert.equal(
    (
      await send(
        "POST",
        "/api/stock-entries",
        { ...input, quantity: 120 },
        staffToken,
      )
    ).statusCode,
    409,
  );
  const out = await send(
    "POST",
    "/api/stock-entries",
    { ...entry("OUT", 20), penId },
    staffToken,
  );
  assert.equal(out.statusCode, 200);
  outId = out.json().entry.id;
  assert.equal(await getStock(), 80);
  assert.equal(
    (await send("POST", "/api/stock-entries", entry("OUT", 100), staffToken))
      .statusCode,
    409,
  );
  const rows = (
    await send(
      "GET",
      `/api/stock-entries?feedId=${feedId}&kind=OUT&from=${now}&to=${now}&status=VALID`,
    )
  ).json();
  assert.equal(rows.total, 1);
  assert.equal(rows.entries[0].penName, "Chuồng 1");
  assert.equal(rows.entries[0].actorName, "Staff");
  assert.equal((await send("DELETE", `/api/feeds/${feedId}`)).statusCode, 409);
});
test("concurrent exports cannot both use same remaining stock; low stock appears in dashboard", async () => {
  const responses = await Promise.all([
    send("POST", "/api/stock-entries", entry("OUT", 50)),
    send("POST", "/api/stock-entries", entry("OUT", 50)),
  ]);
  assert.deepEqual(responses.map((r) => r.statusCode).sort(), [200, 409]);
  assert.equal(await getStock(), 30);
  const dash = (
    await send("GET", "/api/farm/dashboard", undefined, staffToken)
  ).json();
  assert.equal(
    dash.lowStockFeeds.find((f: { id: string }) => f.id === feedId).stock,
    30,
  );
  assert.equal(
    (
      await send("PATCH", `/api/feeds/${feedId}`, {
        code: "F1",
        name: "Cám",
        lowStock: 40,
        active: false,
      })
    ).statusCode,
    409,
  );
});
test("cancellation checks balance, requires admin/reason and retains audit; retry cannot cancel twice", async () => {
  const b = { requestId: randomUUID(), reason: "Nhập nhầm" };
  assert.equal(
    (await send("POST", `/api/stock-entries/${inId}/cancel`, b, staffToken))
      .statusCode,
    403,
  );
  assert.equal(
    (await send("POST", `/api/stock-entries/${inId}/cancel`, b)).statusCode,
    409,
  );
  assert.equal(await getStock(), 30);
  const c = { requestId: randomUUID(), reason: "Xuất nhầm" };
  assert.equal(
    (await send("POST", `/api/stock-entries/${outId}/cancel`, c)).statusCode,
    200,
  );
  assert.equal(await getStock(), 50);
  assert.equal(
    (await send("POST", `/api/stock-entries/${outId}/cancel`, c)).statusCode,
    200,
  );
  assert.equal(await getStock(), 50);
  const list = (
    await send("GET", "/api/stock-entries?status=CANCELLED")
  ).json();
  assert.equal(list.entries[0].cancelReason, "Xuất nhầm");
  assert.equal(list.entries[0].cancelledByName, "Admin");
  assert.equal(
    (await send("GET", `/api/stock-entries?from=${now}&to=2000-01-01`))
      .statusCode,
    400,
  );
  const valid = (
    await send("GET", "/api/stock-entries?kind=OUT&status=VALID")
  ).json().entries[0];
  assert.equal(
    (
      await send("POST", `/api/stock-entries/${valid.id}/cancel`, {
        requestId: randomUUID(),
        reason: "Sai",
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (await send("POST", `/api/stock-entries/${inId}/cancel`, b)).statusCode,
    200,
  );
  assert.equal(await getStock(), 0);
  assert.equal(
    (
      await send("POST", `/api/stock-entries/${inId}/cancel`, {
        ...b,
        requestId: randomUUID(),
      })
    ).statusCode,
    409,
  );
});
test("species preferences persist per user; scoped animal/care/dashboard results agree", async () => {
  const s1 = (
    await send("POST", "/api/farm/species", { name: "Dê mới" })
  ).json().item.id;
  const s2 = (
    await send("POST", "/api/farm/species", { name: "Bò mới" })
  ).json().item.id;
  const breed = (
    await send("POST", "/api/farm/breeds", { name: "Giống mới", speciesId: s1 })
  ).json().item.id;
  const animal = (
    await send("POST", "/api/animals", {
      code: "SELECTED",
      breedId: breed,
      gender: "UNKNOWN",
      arrivalDate: now,
      penId,
    })
  ).json().animal.id;
  await send("POST", "/api/care-tasks", {
    animalId: animal,
    kind: "CHECKUP",
    title: "Kiểm tra",
    dueDate: now,
  });
  assert.equal(
    (
      await send(
        "PATCH",
        "/api/farm/preferences",
        { speciesIds: [s1, s2] },
        staffToken,
      )
    ).statusCode,
    200,
  );
  const p = (
    await send("GET", "/api/farm/preferences", undefined, staffToken)
  ).json();
  assert.equal(p.configured, true);
  assert.equal(p.speciesIds.length, 2);
  assert.equal(
    (await send("GET", "/api/farm/preferences")).json().configured,
    false,
  );
  assert.equal(
    (
      await send(
        "PATCH",
        "/api/farm/preferences",
        { speciesIds: [s1, s1] },
        staffToken,
      )
    ).statusCode,
    400,
  );
  assert.equal(
    (
      await send(
        "PATCH",
        "/api/farm/preferences",
        { speciesIds: [randomUUID()] },
        staffToken,
      )
    ).statusCode,
    409,
  );
  assert.equal(
    (await send("GET", `/api/animals?speciesIds=${s2}`)).json().total,
    0,
  );
  assert.equal(
    (await send("GET", `/api/animals?speciesIds=${s1},${s2}`)).json().total,
    1,
  );
  assert.equal(
    (await send("GET", `/api/care-tasks?speciesIds=${s2}`)).json().total,
    0,
  );
  assert.equal(
    (await send("GET", `/api/farm/dashboard?speciesIds=${s2}`)).json()
      .activeAnimals,
    0,
  );
  assert.equal(
    (await send("GET", `/api/farm/dashboard?speciesIds=${s1}`)).json().due,
    1,
  );
});
test("animal photos are decoded and normalized; update keeps/clears image; invalid image leaves no profile", async () => {
  const species = (await send("GET", "/api/farm/catalogs")).json().species[0]
    .id;
  const breed = (
    await send("POST", "/api/farm/breeds", { name: "Ảnh", speciesId: species })
  ).json().item.id;
  const photo = (
    await sharp({
      create: { width: 800, height: 600, channels: 3, background: "#008844" },
    })
      .png()
      .toBuffer()
  ).toString("base64");
  const body = {
    code: "PHOTO",
    breedId: breed,
    gender: "UNKNOWN",
    arrivalDate: now,
    penId,
    photoBase64: photo,
  };
  const result = await send("POST", "/api/animals", body, staffToken);
  assert.equal(result.statusCode, 200);
  const animalId = result.json().animal.id;
  const profile = (await send("GET", `/api/animals/${animalId}`)).json().animal;
  assert.ok(profile.imageData.startsWith("data:image/jpeg;base64,"));
  const meta = await sharp(
    Buffer.from(profile.imageData.split(",")[1], "base64"),
  ).metadata();
  assert.equal(meta.width, 400);
  assert.equal(meta.exif, undefined);
  const { penId: _, photoBase64: __, ...edit } = body;
  assert.equal(
    (await send("PATCH", `/api/animals/${animalId}`, edit)).statusCode,
    200,
  );
  assert.equal(
    (await send("GET", `/api/animals/${animalId}`)).json().animal.imageData,
    profile.imageData,
  );
  assert.equal(
    (
      await send("PATCH", `/api/animals/${animalId}`, {
        ...edit,
        photoBase64: null,
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (await send("GET", `/api/animals/${animalId}`)).json().animal.imageData,
    null,
  );
  assert.equal(
    (
      await send("POST", "/api/animals", {
        ...body,
        code: "BADPHOTO",
        photoBase64: Buffer.from("<svg/>").toString("base64"),
      })
    ).statusCode,
    400,
  );
  assert.equal(
    (await send("GET", "/api/animals?search=BADPHOTO")).json().total,
    0,
  );
});
