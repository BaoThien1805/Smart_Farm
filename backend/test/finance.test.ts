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
import { hashPassword } from "../src/security.js";

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
    databaseDir = await mkdtemp(path.join(tmpdir(), "smartfarm-finance-test-"));
    const port = 55442;
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
      !path.basename(resolved).startsWith("smartfarm-finance-test-")
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
import { today } from "../src/farm/routes.js";
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
const manual = (kind = "OUT", amount = 300) => ({
  requestId: randomUUID(),
  date: now,
  kind,
  category: "FEED",
  amount,
  content: "Mua thức ăn",
});
async function createAnimal(cap = 2) {
  const key = randomUUID().slice(0, 8);
  const species = (
    await send("POST", "/api/farm/species", { name: "Dê " + key })
  ).json().item.id;
  const breed = (
    await send("POST", "/api/farm/breeds", { name: "Boer", speciesId: species })
  ).json().item.id;
  const area = (
    await send("POST", "/api/farm/areas", { name: "Khu " + key })
  ).json().item.id;
  const pen = (
    await send("POST", "/api/farm/pens", {
      code: key,
      name: "Chuồng " + key,
      areaId: area,
      capacity: cap,
      active: true,
    })
  ).json().item.id;
  const body = {
    code: "AN-" + key,
    breedId: breed,
    gender: "FEMALE",
    arrivalDate: "2026-01-01",
    penId: pen,
  };
  const animal = (await send("POST", "/api/animals", body)).json().animal.id;
  return { animal, pen, body };
}
const saleBody = () => ({
  requestId: randomUUID(),
  date: now,
  amount: 10000000,
  buyer: "Người mua demo",
  notes: "",
});
const cancelBody = (penId: string) => ({
  requestId: randomUUID(),
  reason: "Nhập nhầm",
  penId,
  date: now,
});

test("migration 6 backfills existing owner schemas, preserves farm data and is repeatable", async () => {
  const owner = await app.inject({
    method: "POST",
    url: "/api/auth/register",
    payload: {
      name: "Chủ cũ",
      farmName: "Trại cũ",
      email: "old-owner@test.local",
      password: "Owner-test-password-42",
    },
  });
  assert.equal(owner.statusCode, 201, owner.body);
  const farms = (await pool.query("SELECT schema_name FROM farms")).rows;
  for (const f of farms) {
    assert.match(f.schema_name, /^(public|farm_[a-f0-9]{32})$/);
    await pool.query(
      `DROP TABLE "${f.schema_name}".finance_audit,"${f.schema_name}".finance_entries,"${f.schema_name}".sales`,
    );
  }
  await pool.query("DELETE FROM schema_migrations WHERE version=6");
  await migrate(pool);
  await migrate(pool);
  const report = await send(
    "GET",
    "/api/finance/report",
    undefined,
    owner.json().token,
  );
  assert.equal(report.statusCode, 200, report.body);
  assert.equal(report.json().summary.income, "0");
  assert.equal(
    (
      await send("GET", "/api/farm/catalogs", undefined, owner.json().token)
    ).json().species.length,
    12,
  );
});

test("manual entries validate VND, reserved sales category and access control", async () => {
  for (const path of [
    "/api/finance/entries",
    "/api/finance/report",
    "/api/sales",
    "/api/finance/entries/" + randomUUID() + "/history",
  ])
    assert.equal(
      (await send("GET", path, undefined, staffToken)).statusCode,
      403,
    );
  assert.equal(
    (await send("POST", "/api/finance/entries", manual(), staffToken))
      .statusCode,
    403,
  );
  for (const amount of [0, -1, 1.5, 1000000000001])
    assert.equal(
      (await send("POST", "/api/finance/entries", manual("OUT", amount)))
        .statusCode,
      400,
    );
  assert.equal(
    (
      await send("POST", "/api/finance/entries", {
        ...manual(),
        category: "ANIMAL_SALE",
      })
    ).statusCode,
    400,
  );
  assert.equal(
    (
      await send("POST", "/api/finance/entries", {
        ...manual(),
        date: "2099-01-01",
      })
    ).statusCode,
    409,
  );
  assert.equal(
    (await send("GET", "/api/finance/report?from=2026-03-02&to=2026-03-01"))
      .statusCode,
    400,
  );
  assert.equal(
    (await send("GET", "/api/finance/report?from=1900-01-01&to=2026-01-01"))
      .statusCode,
    400,
  );
});

test("create/edit/cancel manual entries are idempotent and keep complete audit", async () => {
  const body = manual();
  const created = await send("POST", "/api/finance/entries", body);
  assert.equal(created.statusCode, 200, created.body);
  const id = created.json().entry.id;
  assert.equal(
    (await send("POST", "/api/finance/entries", body)).json().entry.id,
    id,
  );
  assert.equal(
    (await send("POST", "/api/finance/entries", { ...body, amount: 999 }))
      .statusCode,
    409,
  );
  const edit = { ...manual("OUT", 550), reason: "Sửa số tiền" };
  assert.equal(
    (await send("PATCH", `/api/finance/entries/${id}`, edit)).statusCode,
    200,
  );
  assert.equal(
    (await send("PATCH", `/api/finance/entries/${id}`, edit)).statusCode,
    200,
  );
  const cancel = { requestId: randomUUID(), reason: "Phiếu nhầm" };
  assert.equal(
    (await send("POST", `/api/finance/entries/${id}/cancel`, cancel))
      .statusCode,
    200,
  );
  assert.equal(
    (await send("POST", `/api/finance/entries/${id}/cancel`, cancel))
      .statusCode,
    200,
  );
  assert.equal(
    (
      await send("PATCH", `/api/finance/entries/${id}`, {
        ...edit,
        requestId: randomUUID(),
      })
    ).statusCode,
    409,
  );
  const history = (
    await send("GET", `/api/finance/entries/${id}/history`)
  ).json().history;
  assert.deepEqual(
    history.map((h: { action: string }) => h.action),
    ["CREATE", "EDIT", "CANCEL"],
  );
  assert.equal(history[1].before.amount, "300");
  assert.equal(history[1].after.amount, "550");
  assert.equal(
    (await send("GET", "/api/finance/entries?status=CANCELLED")).json().total,
    1,
  );
  assert.equal(
    (await send("GET", "/api/finance/entries?page=999")).json().total,
    0,
  );
});

test("selling is atomic, releases capacity, cancels pending care and refuses duplicate/dead/backdated sale", async () => {
  const a = await createAnimal(1);
  const task = (
    await send("POST", "/api/care-tasks", {
      animalId: a.animal,
      kind: "CHECKUP",
      title: "Kiểm tra",
      dueDate: now,
    })
  ).json().task.id;
  assert.equal(
    (
      await send(
        "POST",
        `/api/animals/${a.animal}/sell`,
        saleBody(),
        staffToken,
      )
    ).statusCode,
    403,
  );
  await send("POST", `/api/animals/${a.animal}/weights`, {
    requestId: randomUUID(),
    date: now,
    kg: 30,
  });
  assert.equal(
    (
      await send("POST", `/api/animals/${a.animal}/sell`, {
        ...saleBody(),
        date: "2026-01-01",
      })
    ).statusCode,
    409,
  );
  const b = saleBody();
  const sold = await send("POST", `/api/animals/${a.animal}/sell`, b);
  assert.equal(sold.statusCode, 200, sold.body);
  assert.equal(
    (await send("POST", `/api/animals/${a.animal}/sell`, b)).json().sale.id,
    sold.json().sale.id,
  );
  assert.equal(
    (await send("POST", `/api/animals/${a.animal}/sell`, saleBody()))
      .statusCode,
    409,
  );
  const detail = (await send("GET", `/api/animals/${a.animal}`)).json();
  assert.equal(detail.animal.status, "SOLD");
  assert.equal(
    detail.careTasks.find((t: { id: string }) => t.id === task).status,
    "CANCELLED",
  );
  assert.equal(
    (
      await pool.query(
        "SELECT count(*)::int AS n FROM animals WHERE pen_id=$1 AND status='ACTIVE'",
        [a.pen],
      )
    ).rows[0].n,
    0,
  );
  const totals = (await send("GET", "/api/finance/report")).json().summary;
  assert.equal(totals.salesRevenue, "10000000");
  assert.equal(totals.income, "10000000");
  const monthly = (await send("GET", "/api/farm/dashboard")).json()
    .financeMonthly;
  assert.equal(monthly.length, 6);
  assert.equal(monthly[0].month, now.slice(0, 7));
  assert.equal(monthly[0].salesRevenue, "10000000");
  const e = sold.json().entry.id;
  assert.equal(
    (
      await send("PATCH", `/api/finance/entries/${e}`, {
        ...manual(),
        reason: "Sửa",
      })
    ).statusCode,
    409,
  );
  assert.equal(
    (
      await send("POST", `/api/finance/entries/${e}/cancel`, {
        requestId: randomUUID(),
        reason: "Hủy riêng",
      })
    ).statusCode,
    409,
  );
  const canceled = await send(
    "POST",
    `/api/sales/${sold.json().sale.id}/cancel`,
    cancelBody(a.pen),
  );
  assert.equal(canceled.statusCode, 200, canceled.body);
  const dead = await createAnimal();
  await send("POST", `/api/animals/${dead.animal}/death`, {
    requestId: randomUUID(),
    date: now,
  });
  assert.equal(
    (await send("POST", `/api/animals/${dead.animal}/sell`, saleBody()))
      .statusCode,
    409,
  );
});

test("concurrent sale records one receipt; cancel into a full pen rolls back and retry restores once", async () => {
  const a = await createAnimal(1);
  const results = await Promise.all([
    send("POST", `/api/animals/${a.animal}/sell`, saleBody()),
    send("POST", `/api/animals/${a.animal}/sell`, saleBody()),
  ]);
  assert.deepEqual(results.map((r) => r.statusCode).sort(), [200, 409]);
  const sold = results.find((r) => r.statusCode === 200)!.json();
  const occupant = await send("POST", "/api/animals", {
    ...a.body,
    code: "OCC-" + randomUUID().slice(0, 8),
  });
  assert.equal(occupant.statusCode, 200, occupant.body);
  const b = cancelBody(a.pen);
  assert.equal(
    (await send("POST", `/api/sales/${sold.sale.id}/cancel`, b)).statusCode,
    409,
  );
  assert.equal(
    (await pool.query("SELECT status FROM animals WHERE id=$1", [a.animal]))
      .rows[0].status,
    "SOLD",
  );
  assert.equal(
    (
      await pool.query("SELECT cancelled_at FROM finance_entries WHERE id=$1", [
        sold.entry.id,
      ])
    ).rows[0].cancelled_at,
    null,
  );
  const other = await createAnimal(3);
  b.penId = other.pen;
  assert.equal(
    (await send("POST", `/api/sales/${sold.sale.id}/cancel`, b)).statusCode,
    200,
  );
  assert.equal(
    (await send("POST", `/api/sales/${sold.sale.id}/cancel`, b)).statusCode,
    200,
  );
  const detail = (await send("GET", `/api/animals/${a.animal}`)).json();
  assert.equal(detail.animal.status, "ACTIVE");
  assert.equal(detail.animal.penId, other.pen);
  assert.equal(detail.transfers.length, 1);
  assert.equal(
    (
      await send("POST", `/api/sales/${sold.sale.id}/cancel`, {
        ...b,
        requestId: randomUUID(),
      })
    ).statusCode,
    409,
  );
  // Historic cancelled sale and linked entry are retained after a new sale.
  const again = await send("POST", `/api/animals/${a.animal}/sell`, saleBody());
  assert.equal(again.statusCode, 200, again.body);
  assert.equal(
    (await send("GET", `/api/sales?animalId=${a.animal}&status=ALL`)).json()
      .total,
    2,
  );
  await send(
    "POST",
    `/api/sales/${again.json().sale.id}/cancel`,
    cancelBody(other.pen),
  );
});

test("reports total valid entries once, include zero months and dashboard never returns finance to staff", async () => {
  const credit = await send("POST", "/api/finance/entries", {
    ...manual("IN", 2000),
    category: "OTHER",
    date: "2026-01-10",
  });
  assert.equal(credit.statusCode, 200, credit.body);
  const debit = await send("POST", "/api/finance/entries", {
    ...manual("OUT", 500),
    date: "2026-01-11",
  });
  assert.equal(debit.statusCode, 200, debit.body);
  const report = await send(
    "GET",
    "/api/finance/report?from=2026-01-01&to=2026-03-31",
  );
  assert.deepEqual(report.json().summary, {
    salesRevenue: "0",
    income: "2000",
    expense: "500",
    difference: "1500",
  });
  assert.equal(report.json().monthly.length, 3);
  assert.deepEqual(report.json().monthly[1], {
    month: "2026-02",
    income: "0",
    expense: "0",
  });
  assert.equal(
    (
      await send(
        "GET",
        "/api/finance/entries?from=2026-01-01&to=2026-03-31&kind=OUT&category=FEED",
      )
    ).json().total,
    1,
  );
  const admin = await send("GET", "/api/farm/dashboard");
  assert.equal(typeof admin.json().finance.income, "string");
  const staff = await send("GET", "/api/farm/dashboard", undefined, staffToken);
  assert.equal("finance" in staff.json(), false);
  assert.equal("financeMonthly" in staff.json(), false);
  const profile = await send("GET", "/api/animals", undefined, staffToken);
  assert.equal(profile.body.includes("amount"), false);
});

test("financial data and sale IDs stay isolated between owners, including new registrations", async () => {
  const owner = await app.inject({
    method: "POST",
    url: "/api/auth/register",
    payload: {
      name: "Chủ mới",
      farmName: "Trại mới",
      email: "finance-owner@test.local",
      password: "Owner-test-password-42",
    },
  });
  assert.equal(owner.statusCode, 201, owner.body);
  const token = owner.json().token;
  const entries = (
    await send("GET", "/api/finance/entries?from=2026-01-01&to=" + now)
  ).json().entries;
  assert.ok(entries.length > 0);
  assert.equal(
    (await send("GET", "/api/finance/entries", undefined, token)).json().total,
    0,
  );
  assert.equal(
    (
      await send(
        "GET",
        `/api/finance/entries/${entries[0].id}/history`,
        undefined,
        token,
      )
    ).statusCode,
    404,
  );
  assert.equal(
    (
      await send(
        "POST",
        `/api/finance/entries/${entries[0].id}/cancel`,
        { requestId: randomUUID(), reason: "Từ chủ khác" },
        token,
      )
    ).statusCode,
    404,
  );
  const sales = (await send("GET", "/api/sales?status=ALL")).json().sales;
  assert.equal(
    (await send("GET", "/api/sales?status=ALL", undefined, token)).json().total,
    0,
  );
  assert.equal(
    (
      await send(
        "POST",
        `/api/sales/${sales[0].id}/cancel`,
        cancelBody(randomUUID()),
        token,
      )
    ).statusCode,
    404,
  );
});

test("failure after writing a sale rolls back sale, receipt, animal and care together", async () => {
  const a = await createAnimal();
  const task = await send("POST", "/api/care-tasks", {
    animalId: a.animal,
    kind: "CHECKUP",
    title: "Lịch còn chờ",
    dueDate: now,
  });
  assert.equal(task.statusCode, 200, task.body);
  await pool.query(
    `CREATE FUNCTION phase5_test_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'Injected test failure'; END $$; CREATE TRIGGER phase5_test_failure AFTER INSERT ON finance_entries FOR EACH ROW WHEN (NEW.category='ANIMAL_SALE') EXECUTE FUNCTION phase5_test_failure()`,
  );
  try {
    assert.equal(
      (await send("POST", `/api/animals/${a.animal}/sell`, saleBody()))
        .statusCode,
      500,
    );
    assert.equal(
      (
        await pool.query(
          "SELECT count(*)::int AS n FROM sales WHERE animal_id=$1",
          [a.animal],
        )
      ).rows[0].n,
      0,
    );
    const detail = (await send("GET", `/api/animals/${a.animal}`)).json();
    assert.equal(detail.animal.status, "ACTIVE");
    assert.equal(detail.careTasks[0].status, "PENDING");
  } finally {
    await pool.query(
      "DROP TRIGGER phase5_test_failure ON finance_entries; DROP FUNCTION phase5_test_failure()",
    );
  }
});

test("concurrent cancellation cannot overfill the final pen slot", async () => {
  const first = await createAnimal(),
    second = await createAnimal(),
    target = await createAnimal(2);
  const saleA = (
    await send("POST", `/api/animals/${first.animal}/sell`, saleBody())
  ).json().sale.id;
  const saleB = (
    await send("POST", `/api/animals/${second.animal}/sell`, saleBody())
  ).json().sale.id;
  const results = await Promise.all([
    send("POST", `/api/sales/${saleA}/cancel`, cancelBody(target.pen)),
    send("POST", `/api/sales/${saleB}/cancel`, cancelBody(target.pen)),
  ]);
  assert.deepEqual(results.map((r) => r.statusCode).sort(), [200, 409]);
  const capacity = (
    await pool.query(
      "SELECT count(*)::int AS n FROM animals WHERE pen_id=$1 AND status='ACTIVE'",
      [target.pen],
    )
  ).rows[0].n;
  assert.equal(capacity, 2);
});

const batchCall = (
  method: "GET" | "POST",
  url: string,
  payload?: object,
  token = adminToken,
) =>
  app.inject({
    method,
    url,
    remoteAddress: "127.0.0.92",
    headers: authorization(token),
    ...(payload ? { payload } : {}),
  });
async function batchGroup(count: number) {
  const key = "BATCH-" + randomUUID().slice(0, 8);
  const species = (
    await batchCall("POST", "/api/farm/species", { name: key })
  ).json().item.id;
  const breed = (
    await batchCall("POST", "/api/farm/breeds", {
      name: key,
      speciesId: species,
    })
  ).json().item.id;
  const area = (
    await batchCall("POST", "/api/farm/areas", { name: key })
  ).json().item.id;
  const pen = (
    await batchCall("POST", "/api/farm/pens", {
      name: key,
      code: key,
      areaId: area,
      capacity: 10,
    })
  ).json().item.id;
  const ids: string[] = [];
  for (let i = 0; i < count; i++) {
    const result = await batchCall("POST", "/api/animals", {
      code: `${key}-${i}`,
      breedId: breed,
      gender: "FEMALE",
      arrivalDate: "2026-01-01",
      penId: pen,
      notes: "Ghi chú ban đầu",
    });
    assert.equal(result.statusCode, 200, result.body);
    ids.push(result.json().animal.id);
  }
  ids.sort();
  for (const id of ids) {
    const result = await batchCall("POST", "/api/care-tasks", {
      animalId: id,
      kind: "CHECKUP",
      title: key,
      dueDate: now,
    });
    assert.equal(result.statusCode, 200, result.body);
  }
  return { ids, pen };
}

test("batch selling creates one audited receipt per selected animal, retries once and preserves single-sale cancellation", async () => {
  const group = await batchGroup(3);
  const body = {
    requestId: randomUUID(),
    date: now,
    buyer: "Người mua theo đợt",
    notes: "Bán hai con",
    items: [
      { animalId: group.ids[0], amount: 1000000 },
      { animalId: group.ids[1], amount: 2000000 },
    ],
  };
  const [first, retry] = await Promise.all([
    batchCall("POST", "/api/animals/batch/sell", body),
    batchCall("POST", "/api/animals/batch/sell", body),
  ]);
  assert.equal(first.statusCode, 200, first.body);
  assert.deepEqual(first.json(), retry.json());
  assert.equal(first.json().count, 2);
  assert.equal(first.json().totalAmount, "3000000");
  const rows = await pool.query(
    "SELECT s.animal_id,e.amount::text,(SELECT count(*)::int FROM finance_audit a WHERE a.entry_id=e.id) AS audit FROM sales s JOIN finance_entries e ON e.sale_id=s.id WHERE s.animal_id=ANY($1::uuid[])",
    [group.ids],
  );
  assert.equal(rows.rows.length, 2);
  assert.equal(
    rows.rows.reduce((sum, r) => sum + Number(r.amount), 0),
    3000000,
  );
  assert.ok(rows.rows.every((r) => r.audit === 1));
  for (const id of group.ids.slice(0, 2)) {
    const detail = (await batchCall("GET", `/api/animals/${id}`)).json();
    assert.equal(detail.animal.status, "SOLD");
    assert.equal(detail.careTasks[0].status, "CANCELLED");
  }
  const untouched = (
    await batchCall("GET", `/api/animals/${group.ids[2]}`)
  ).json();
  assert.equal(untouched.animal.status, "ACTIVE");
  assert.equal(untouched.careTasks[0].status, "PENDING");
  assert.equal(
    (
      await batchCall("POST", "/api/animals/batch/sell", {
        ...body,
        requestId: randomUUID(),
      })
    ).statusCode,
    409,
  );
  assert.equal(
    (
      await batchCall("POST", "/api/animals/batch/sell", {
        ...body,
        buyer: "Đổi nội dung",
      })
    ).statusCode,
    409,
  );
  const sale = first.json().sales[0];
  const cancelled = await batchCall(
    "POST",
    `/api/sales/${sale.saleId}/cancel`,
    cancelBody(group.pen),
  );
  assert.equal(cancelled.statusCode, 200, cancelled.body);
  assert.equal(
    (await batchCall("GET", `/api/animals/${sale.animalId}`)).json().animal
      .status,
    "ACTIVE",
  );
  assert.ok(
    (
      await batchCall("GET", `/api/sales?animalId=${sale.animalId}&status=ALL`)
    ).json().sales[0].cancelledAt,
  );
  for (const invalid of [
    { items: [] },
    { items: [body.items[0], body.items[0]] },
    { items: [{ animalId: group.ids[2], amount: 0 }] },
    { items: [{ animalId: group.ids[2], amount: 1.5 }] },
    { requestId: undefined },
  ]) {
    assert.equal(
      (
        await batchCall("POST", "/api/animals/batch/sell", {
          ...body,
          ...invalid,
        })
      ).statusCode,
      400,
    );
  }
});

test("batch sale rolls back earlier animals, receipts, audit and care when a later animal has newer history", async () => {
  const group = await batchGroup(2);
  await batchCall("POST", `/api/animals/${group.ids[1]}/weights`, {
    requestId: randomUUID(),
    date: now,
    kg: 20,
    notes: "",
  });
  const yesterday = new Date(`${now}T00:00:00Z`);
  yesterday.setUTCDate(yesterday.getUTCDate() - 1);
  const response = await batchCall("POST", "/api/animals/batch/sell", {
    requestId: randomUUID(),
    date: yesterday.toISOString().slice(0, 10),
    items: group.ids.map((animalId) => ({ animalId, amount: 1000000 })),
  });
  assert.equal(response.statusCode, 409, response.body);
  assert.equal(
    (
      await pool.query(
        "SELECT count(*)::int AS n FROM sales WHERE animal_id=ANY($1::uuid[])",
        [group.ids],
      )
    ).rows[0].n,
    0,
  );
  for (const id of group.ids) {
    const detail = (await batchCall("GET", `/api/animals/${id}`)).json();
    assert.equal(detail.animal.status, "ACTIVE");
    assert.equal(detail.careTasks[0].status, "PENDING");
  }
});

test("batch death is atomic and idempotent, preserves history and notes, cancels care without creating income", async () => {
  const group = await batchGroup(3);
  await batchCall("POST", `/api/animals/${group.ids[1]}/weights`, {
    requestId: randomUUID(),
    date: now,
    kg: 22,
    notes: "",
  });
  const ids = group.ids.slice(0, 2);
  const body = {
    requestId: randomUUID(),
    date: now,
    notes: "Ghi nhận chết theo đợt",
    animalIds: ids,
  };
  const yesterday = new Date(`${now}T00:00:00Z`);
  yesterday.setUTCDate(yesterday.getUTCDate() - 1);
  assert.equal(
    (
      await batchCall("POST", "/api/animals/batch/death", {
        ...body,
        date: yesterday.toISOString().slice(0, 10),
      })
    ).statusCode,
    409,
  );
  for (const id of ids) {
    const detail = (await batchCall("GET", `/api/animals/${id}`)).json();
    assert.equal(detail.animal.status, "ACTIVE");
    assert.equal(detail.careTasks[0].status, "PENDING");
  }
  assert.equal(
    (
      await batchCall("POST", "/api/animals/batch/death", {
        ...body,
        animalIds: [ids[0], randomUUID()],
      })
    ).statusCode,
    404,
  );
  const before = (
    await pool.query("SELECT count(*)::int AS n FROM finance_entries")
  ).rows[0].n;
  const [first, retry] = await Promise.all([
    batchCall("POST", "/api/animals/batch/death", body),
    batchCall("POST", "/api/animals/batch/death", body),
  ]);
  assert.equal(first.statusCode, 200, first.body);
  assert.deepEqual(first.json(), retry.json());
  assert.equal(first.json().count, 2);
  for (const id of ids) {
    const detail = (await batchCall("GET", `/api/animals/${id}`)).json();
    assert.equal(detail.animal.status, "DEAD");
    assert.equal(detail.careTasks[0].status, "CANCELLED");
    assert.ok(detail.animal.notes.includes("Ghi chú ban đầu"));
    assert.equal(detail.animal.notes.split(body.notes).length, 2);
  }
  assert.equal(
    (await batchCall("GET", `/api/animals/${ids[1]}`)).json().weights.length,
    1,
  );
  assert.equal(
    (await batchCall("GET", `/api/animals/${group.ids[2]}`)).json().animal
      .status,
    "ACTIVE",
  );
  assert.equal(
    (await pool.query("SELECT count(*)::int AS n FROM finance_entries")).rows[0]
      .n,
    before,
  );
  assert.equal(
    (
      await batchCall("POST", "/api/animals/batch/death", {
        ...body,
        requestId: randomUUID(),
      })
    ).statusCode,
    409,
  );
  assert.equal(
    (
      await batchCall("POST", "/api/animals/batch/death", {
        ...body,
        animalIds: [],
      })
    ).statusCode,
    400,
  );
});

test("batch sale and death stay admin-only and cannot touch animals in another farm", async () => {
  const group = await batchGroup(1);
  const death = { requestId: randomUUID(), date: now, animalIds: group.ids };
  const sale = {
    requestId: randomUUID(),
    date: now,
    items: group.ids.map((animalId) => ({ animalId, amount: 1000000 })),
  };
  for (const role of ["STAFF", "VET", "ACCOUNTANT"]) {
    let token = staffToken;
    if (role !== "STAFF") {
      const email = `batch-lifecycle-${role.toLowerCase()}@test.local`;
      const created = await batchCall("POST", "/api/users", {
        name: role,
        email,
        role,
        password: staffPassword,
      });
      assert.equal(created.statusCode, 201, created.body);
      token = (
        await batchCall("POST", "/api/auth/login", {
          email,
          password: staffPassword,
        })
      ).json().token;
    }
    assert.equal(
      (await batchCall("POST", "/api/animals/batch/sell", sale, token))
        .statusCode,
      403,
    );
    assert.equal(
      (await batchCall("POST", "/api/animals/batch/death", death, token))
        .statusCode,
      403,
    );
  }
  const owner = await app.inject({
    method: "POST",
    url: "/api/auth/register",
    remoteAddress: "127.0.0.93",
    payload: {
      name: "Chủ đối chứng",
      farmName: "Trại đối chứng batch",
      email: "batch-lifecycle-owner@test.local",
      password: staffPassword,
    },
  });
  assert.equal(owner.statusCode, 201, owner.body);
  assert.equal(
    (
      await batchCall(
        "POST",
        "/api/animals/batch/sell",
        sale,
        owner.json().token,
      )
    ).statusCode,
    404,
  );
  assert.equal(
    (
      await batchCall(
        "POST",
        "/api/animals/batch/death",
        death,
        owner.json().token,
      )
    ).statusCode,
    404,
  );
  const detail = (
    await batchCall("GET", `/api/animals/${group.ids[0]}`)
  ).json();
  assert.equal(detail.animal.status, "ACTIVE");
});
