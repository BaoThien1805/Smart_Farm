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
import { codePrefix } from "../src/codes.js";

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
    databaseDir = await mkdtemp(path.join(tmpdir(), "smartfarm-roles-test-"));
    const port = 55443;
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
      !path.basename(resolved).startsWith("smartfarm-roles-test-")
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

let vetToken: string, accountantToken: string;
test("owner creates professional roles; neither role can manage personnel or operating data", async () => {
  for (const role of ["VET", "ACCOUNTANT"] as const) {
    const email = role.toLowerCase() + "@test.local";
    const created = await send("POST", "/api/users", {
      name: role,
      email,
      password: staffPassword,
      role,
    });
    assert.equal(created.statusCode, 201, created.body);
    assert.equal(created.json().user.role, role);
    const login = await app.inject({
      method: "POST",
      url: "/api/auth/login",
      payload: { email, password: staffPassword },
    });
    assert.equal(login.statusCode, 200, login.body);
    const token = login.json().token;
    if (role === "VET") vetToken = token;
    else accountantToken = token;
    for (const [method, url] of [
      ["GET", "/api/users"],
      ["POST", "/api/users"],
      ["POST", "/api/animals"],
      ["PATCH", "/api/animals/" + randomUUID()],
      ["POST", "/api/animals/" + randomUUID() + "/weights"],
      ["POST", "/api/animals/" + randomUUID() + "/transfer"],
      ["POST", "/api/stock-entries"],
      ["POST", "/api/farm/species"],
      ["PATCH", "/api/farm/location"],
    ] as const)
      assert.equal((await send(method, url, {}, token)).statusCode, 403, url);
    for (const path of [
      "/api/animals",
      "/api/farm/catalogs",
      "/api/care-tasks",
    ])
      assert.equal(
        (await send("GET", path, undefined, token)).statusCode,
        200,
        path,
      );
  }
  assert.equal(
    (
      await send("POST", "/api/users", {
        name: "Invalid",
        email: "invalid@test.local",
        password: staffPassword,
        role: "ADMIN",
      })
    ).statusCode,
    400,
  );
});

test("vet exams validate clinical data, keep actor and are idempotent; staff cannot write diagnoses", async () => {
  const { animal: id } = await createAnimal();
  const body = {
    requestId: randomUUID(),
    date: now,
    content: "Khám định kỳ",
    status: "NEEDS_CARE",
    diagnosis: "Viêm da",
    treatment: "Theo dõi và tái khám",
    notes: "",
  };
  for (const token of [staffToken, accountantToken])
    assert.equal(
      (await send("POST", `/api/animals/${id}/exams`, body, token)).statusCode,
      403,
    );
  assert.equal(
    (
      await send(
        "POST",
        `/api/animals/${id}/exams`,
        { ...body, diagnosis: " " },
        vetToken,
      )
    ).statusCode,
    400,
  );
  assert.equal(
    (
      await send(
        "POST",
        `/api/animals/${id}/exams`,
        { ...body, date: "2099-01-01" },
        vetToken,
      )
    ).statusCode,
    409,
  );
  for (let i = 0; i < 2; i++)
    assert.equal(
      (await send("POST", `/api/animals/${id}/exams`, body, vetToken))
        .statusCode,
      200,
    );
  assert.equal(
    (
      await send(
        "POST",
        `/api/animals/${id}/exams`,
        { ...body, treatment: "Thay đổi" },
        vetToken,
      )
    ).statusCode,
    409,
  );
  const detail = (
    await send("GET", `/api/animals/${id}`, undefined, staffToken)
  ).json();
  assert.equal(detail.healthRecords.length, 1);
  assert.equal(detail.healthRecords[0].recordType, "EXAM");
  assert.equal(detail.healthRecords[0].diagnosis, body.diagnosis);
  assert.equal(detail.healthRecords[0].treatment, body.treatment);
  assert.equal(detail.healthRecords[0].actorName, "VET");
  assert.equal(detail.animal.healthStatus, "NEEDS_CARE");
  assert.equal(
    (
      await send(
        "POST",
        `/api/animals/${id}/health`,
        {
          requestId: randomUUID(),
          date: now,
          content: "Theo dõi",
          status: "NORMAL",
          diagnosis: "Vượt quyền",
        },
        staffToken,
      )
    ).statusCode,
    400,
  );
  const care = {
    animalId: id,
    kind: "CHECKUP",
    title: "Tái khám",
    dueDate: now,
    notes: "",
  };
  assert.equal(
    (await send("POST", "/api/care-tasks", care, vetToken)).statusCode,
    200,
  );
  assert.equal(
    (await send("POST", "/api/care-tasks", care, accountantToken)).statusCode,
    403,
  );
});

test("accountant manages manual finances and reports but cannot sell or cancel a sale", async () => {
  const created = await send(
    "POST",
    "/api/finance/entries",
    manual(),
    accountantToken,
  );
  assert.equal(created.statusCode, 200, created.body);
  const id = created.json().entry.id;
  const changed = await send(
    "PATCH",
    `/api/finance/entries/${id}`,
    { ...manual(), amount: 500, reason: "Sửa chứng từ" },
    accountantToken,
  );
  assert.equal(changed.statusCode, 200, changed.body);
  assert.equal(
    (
      await send(
        "GET",
        `/api/finance/entries/${id}/history`,
        undefined,
        accountantToken,
      )
    ).statusCode,
    200,
  );
  assert.equal(
    (
      await send(
        "POST",
        `/api/finance/entries/${id}/cancel`,
        { requestId: randomUUID(), reason: "Phiếu nhầm" },
        accountantToken,
      )
    ).statusCode,
    200,
  );
  for (const path of [
    "/api/finance/entries",
    "/api/finance/report",
    "/api/sales",
  ]) {
    assert.equal(
      (await send("GET", path, undefined, accountantToken)).statusCode,
      200,
    );
    assert.equal(
      (await send("GET", path, undefined, vetToken)).statusCode,
      403,
    );
  }
  const { animal: idAnimal, pen } = await createAnimal();
  assert.equal(
    (
      await send(
        "POST",
        `/api/animals/${idAnimal}/sell`,
        saleBody(),
        accountantToken,
      )
    ).statusCode,
    403,
  );
  const sold = await send("POST", `/api/animals/${idAnimal}/sell`, saleBody());
  assert.equal(sold.statusCode, 200, sold.body);
  const saleId = (
    await send(
      "GET",
      `/api/sales?animalId=${idAnimal}`,
      undefined,
      accountantToken,
    )
  ).json().sales[0].id;
  assert.equal(
    (
      await send(
        "POST",
        `/api/sales/${saleId}/cancel`,
        cancelBody(pen),
        accountantToken,
      )
    ).statusCode,
    403,
  );
  assert.ok(
    (
      await send("GET", "/api/farm/dashboard", undefined, accountantToken)
    ).json().finance,
  );
  assert.equal(
    (await send("GET", "/api/farm/dashboard", undefined, vetToken)).json()
      .finance,
    undefined,
  );
});

test("new farm clinical tables and professional sessions stay isolated and lock revokes access", async () => {
  const owner = await app.inject({
    method: "POST",
    url: "/api/auth/register",
    payload: {
      name: "Chủ mới",
      farmName: "Trại mới",
      email: "roles-owner@test.local",
      password: staffPassword,
    },
  });
  assert.equal(owner.statusCode, 201, owner.body);
  const token = owner.json().token;
  const created = await send(
    "POST",
    "/api/users",
    {
      name: "Bác sĩ mới",
      email: "isolated-vet@test.local",
      password: staffPassword,
      role: "VET",
    },
    token,
  );
  assert.equal(created.statusCode, 201, created.body);
  const vet = (
    await app.inject({
      method: "POST",
      url: "/api/auth/login",
      payload: { email: "isolated-vet@test.local", password: staffPassword },
    })
  ).json().token;
  const { animal: id } = await createAnimal();
  assert.equal(
    (await send("GET", `/api/animals/${id}`, undefined, vet)).statusCode,
    404,
  );
  const schema = (
    await pool.query("SELECT schema_name FROM farms WHERE id=$1", [
      owner.json().user.farmId,
    ])
  ).rows[0].schema_name;
  assert.match(schema, /^farm_[a-f0-9]{32}$/);
  assert.equal(
    (
      await pool.query(
        `SELECT diagnosis,treatment,record_type FROM "${schema}".health_records`,
      )
    ).rowCount,
    0,
  );
  assert.equal(
    (
      await send(
        "PATCH",
        `/api/users/${created.json().user.id}/status`,
        { active: false },
        token,
      )
    ).statusCode,
    200,
  );
  assert.equal(
    (await send("GET", "/api/auth/me", undefined, vet)).statusCode,
    401,
  );
  await migrate(pool);
});

test("staff cannot confirm care; vet confirms once with actor history", async () => {
  const { animal: id } = await createAnimal();
  const task = await send(
    "POST",
    "/api/care-tasks",
    {
      animalId: id,
      kind: "CHECKUP",
      title: "Xác nhận thú y",
      dueDate: now,
      notes: "",
    },
    staffToken,
  );
  assert.equal(task.statusCode, 200, task.body);
  const taskId = task.json().task.id;
  const body = {
    requestId: randomUUID(),
    date: now,
    status: "NORMAL",
    notes: "Đã kiểm tra",
  };
  assert.equal(
    (await send("POST", `/api/care-tasks/${taskId}/complete`, body, staffToken))
      .statusCode,
    403,
  );
  for (let i = 0; i < 2; i++)
    assert.equal(
      (await send("POST", `/api/care-tasks/${taskId}/complete`, body, vetToken))
        .statusCode,
      200,
    );
  const history = (await send("GET", `/api/animals/${id}`)).json()
    .healthRecords;
  assert.equal(history.length, 1);
  assert.equal(history[0].actorName, "VET");
});

test("only owner updates or removes user avatar; invalid images and other farms are rejected", async () => {
  const { default: sharp } = await import("sharp");
  const image = (
    await sharp({
      create: { width: 8, height: 8, channels: 3, background: "#339944" },
    })
      .png()
      .toBuffer()
  ).toString("base64");
  const path = `/api/users/${staffId}/avatar`;
  assert.equal(
    (await send("PATCH", path, { photoBase64: image }, staffToken)).statusCode,
    403,
  );
  assert.equal(
    (await send("PATCH", path, { photoBase64: image }, vetToken)).statusCode,
    403,
  );
  const saved = await send("PATCH", path, { photoBase64: image });
  assert.equal(saved.statusCode, 200, saved.body);
  assert.match(saved.json().user.avatarData, /^data:image\/jpeg;base64,/);
  assert.equal(
    (await send("GET", "/api/auth/me", undefined, staffToken)).json().user
      .avatarData,
    saved.json().user.avatarData,
  );
  assert.equal(
    (await send("PATCH", path, { photoBase64: "bad-image" })).statusCode,
    400,
  );
  const owner = await app.inject({
    method: "POST",
    url: "/api/auth/register",
    payload: {
      name: "Chủ khác",
      farmName: "Trại ảnh",
      email: "avatar-owner@test.local",
      password: staffPassword,
    },
  });
  assert.equal(owner.statusCode, 201, owner.body);
  assert.equal(
    (await send("PATCH", path, { photoBase64: image }, owner.json().token))
      .statusCode,
    404,
  );
  assert.equal(
    (await send("PATCH", path, { photoBase64: null })).json().user.avatarData,
    null,
  );
});

test("farm species persist for owner and staff; adding an unused default or new species extends the shared list", async () => {
  const owner = await app.inject({
    method: "POST",
    url: "/api/auth/register",
    payload: {
      name: "Chủ loài",
      farmName: "Trại loài",
      email: "species-owner@test.local",
      password: staffPassword,
    },
  });
  assert.equal(owner.statusCode, 201, owner.body);
  const token = owner.json().token;
  const all = (await send("GET", "/api/farm/catalogs", undefined, token)).json()
    .species;
  const cow = all.find((s: { name: string }) => s.name === "Bò");
  assert.equal(
    (
      await send(
        "PATCH",
        "/api/farm/preferences",
        { speciesIds: [cow.id] },
        token,
      )
    ).statusCode,
    200,
  );
  const settings = (
    await send("GET", "/api/farm/species-settings", undefined, token)
  ).json();
  assert.equal(settings.configured, true);
  assert.deepEqual(settings.speciesIds, [cow.id]);
  assert.deepEqual(
    (await send("GET", "/api/farm/catalogs", undefined, token))
      .json()
      .species.map((s: { name: string }) => s.name),
    ["Bò"],
  );
  const staff = await send(
    "POST",
    "/api/users",
    {
      name: "Nhân viên loài",
      email: "species-staff@test.local",
      password: staffPassword,
    },
    token,
  );
  assert.equal(staff.statusCode, 201, staff.body);
  const session = (
    await app.inject({
      method: "POST",
      url: "/api/auth/login",
      payload: { email: "species-staff@test.local", password: staffPassword },
    })
  ).json().token;
  assert.equal(
    (await send("GET", "/api/farm/catalogs", undefined, session)).json().species
      .length,
    1,
  );
  assert.equal(
    (
      await send(
        "GET",
        "/api/farm/catalogs?includeAvailable=true",
        undefined,
        session,
      )
    ).statusCode,
    403,
  );
  assert.equal(
    (await send("POST", "/api/farm/species", { name: "Dê" }, token)).statusCode,
    200,
  );
  assert.equal(
    (await send("POST", "/api/farm/species", { name: "Lạc đà" }, token))
      .statusCode,
    200,
  );
  assert.deepEqual(
    (await send("GET", "/api/farm/catalogs", undefined, session))
      .json()
      .species.map((s: { name: string }) => s.name)
      .sort(),
    ["Bò", "Dê", "Lạc đà"].sort(),
  );
  assert.equal(
    (await send("POST", "/api/farm/species", { name: "Bò" }, token)).statusCode,
    409,
  );
  assert.equal(
    (await send("PATCH", "/api/farm/preferences", { speciesIds: [] }, token))
      .statusCode,
    400,
  );
  assert.equal(
    (
      await send(
        "GET",
        "/api/farm/catalogs?includeAvailable=true",
        undefined,
        token,
      )
    ).json().species.length,
    13,
  );
});

test("migration 9 preserves legacy all-species selection and is repeatable", async () => {
  const owner = await app.inject({
    method: "POST",
    url: "/api/auth/register",
    payload: {
      name: "Chủ cũ",
      farmName: "Trại lựa chọn cũ",
      email: "legacy-selection@test.local",
      password: staffPassword,
    },
  });
  assert.equal(owner.statusCode, 201, owner.body);
  const user = owner.json().user;
  const schema = (
    await pool.query("SELECT schema_name FROM public.farms WHERE id=$1", [
      user.farmId,
    ])
  ).rows[0].schema_name;
  assert.match(schema, /^farm_[a-f0-9]{32}$/);
  await pool.query(
    `INSERT INTO "${schema}".user_species_preferences(user_id,configured) VALUES($1,true)`,
    [user.id],
  );
  // Simulate the previous migration version only in this isolated test database.
  await pool.query(
    "ALTER TABLE public.users DROP COLUMN avatar_data; DELETE FROM public.schema_migrations WHERE version=9",
  );
  await migrate(pool);
  await migrate(pool);
  const selection = (
    await send(
      "GET",
      "/api/farm/species-settings",
      undefined,
      owner.json().token,
    )
  ).json();
  assert.equal(selection.configured, true);
  assert.equal(selection.speciesIds.length, 12);
  assert.equal(
    (
      await send("GET", "/api/farm/catalogs", undefined, owner.json().token)
    ).json().species.length,
    12,
  );
  assert.equal(
    (await send("GET", "/api/auth/me", undefined, owner.json().token)).json()
      .user.avatarData,
    null,
  );
});

const sendNew = (
  method: "GET" | "POST" | "PATCH" | "DELETE",
  url: string,
  payload?: object,
  token = adminToken,
) =>
  app.inject({
    method,
    url,
    remoteAddress: "127.0.0.20",
    headers: authorization(token),
    ...(payload ? { payload } : {}),
  });

test("codes use abbreviations, database history and farm boundaries; migration preserves them", async () => {
  assert.equal(codePrefix("animals", "BBB"), "BBB");
  assert.equal(codePrefix("pens", "Chuồng bò phía Đông"), "CBPD");
  assert.equal(codePrefix("users", "Tên nhân viên rất dài"), "NV");
  const owner = await app.inject({
    method: "POST",
    url: "/api/auth/register",
    payload: {
      name: "Chủ mã",
      farmName: "Trang trại mã",
      email: "codes@test.local",
      password: staffPassword,
    },
  });
  assert.equal(owner.statusCode, 201, owner.body);
  const token = owner.json().token;
  const area = await sendNew(
    "POST",
    "/api/farm/areas",
    { name: "Khu phía Bắc", code: "KPB-09" },
    token,
  );
  assert.equal(area.statusCode, 200, area.body);
  assert.equal(
    (
      await sendNew(
        "GET",
        "/api/code-suggestion?kind=areas&name=Khu%20ph%C3%ADa%20B%E1%BA%AFc",
        undefined,
        token,
      )
    ).json().code,
    "KPB-10",
  );
  assert.equal(
    (
      await sendNew(
        "POST",
        "/api/farm/areas",
        { name: "Khu khác", code: "kpb-09" },
        token,
      )
    ).statusCode,
    409,
  );
  const catalog = (
    await sendNew("GET", "/api/farm/catalogs", undefined, token)
  ).json();
  const breed = await sendNew(
    "POST",
    "/api/farm/breeds",
    { name: "BBB", speciesId: catalog.species[0].id },
    token,
  );
  assert.equal(breed.statusCode, 200, breed.body);
  const pen = await sendNew(
    "POST",
    "/api/farm/pens",
    {
      name: "Chuồng bò",
      code: "CB-01",
      areaId: area.json().item.id,
      capacity: 10,
    },
    token,
  );
  assert.equal(pen.statusCode, 200, pen.body);
  for (const code of ["BBB_01", "BBB_03"]) {
    const result = await sendNew(
      "POST",
      "/api/animals",
      {
        code,
        breedId: breed.json().item.id,
        penId: pen.json().item.id,
        gender: "UNKNOWN",
        arrivalDate: new Date().toISOString().slice(0, 10),
      },
      token,
    );
    assert.equal(result.statusCode, 200, result.body);
  }
  assert.equal(
    (
      await sendNew(
        "GET",
        "/api/code-suggestion?kind=animals&name=BBB",
        undefined,
        token,
      )
    ).json().code,
    "BBB_04",
  );
  assert.equal(
    (
      await sendNew(
        "GET",
        "/api/code-suggestion?kind=animals&name=BBB",
        undefined,
        adminToken,
      )
    ).json().code,
    "BBB_01",
  );
  const workers = await Promise.all(
    [1, 2].map((n) =>
      sendNew(
        "POST",
        "/api/users",
        {
          name: `Nhân viên ${n}`,
          email: `codes-worker-${n}@test.local`,
          password: staffPassword,
        },
        token,
      ),
    ),
  );
  for (const worker of workers)
    assert.equal(worker.statusCode, 201, worker.body);
  assert.deepEqual(workers.map((w) => w.json().user.code).sort(), [
    "NV-01",
    "NV-02",
  ]);
  await migrate(pool);
  await migrate(pool);
  assert.equal(
    (await sendNew("GET", "/api/farm/catalogs", undefined, token)).json()
      .areas[0].code,
    "KPB-09",
  );
  assert.equal(
    (
      await sendNew("GET", "/api/code-suggestion?kind=users", undefined, token)
    ).json().code,
    "NV-03",
  );
  assert.equal(
    (
      await sendNew(
        "GET",
        "/api/code-suggestion?kind=users",
        undefined,
        staffToken,
      )
    ).statusCode,
    403,
  );
  assert.equal(
    (
      await sendNew(
        "GET",
        "/api/code-suggestion?kind=users;DROP",
        undefined,
        token,
      )
    ).statusCode,
    400,
  );
});

test("owner edits personnel atomically; protects ownership and revokes changed-role sessions", async () => {
  const made = await sendNew("POST", "/api/users", {
    name: "Nhân viên sửa",
    email: "edit-worker@test.local",
    password: staffPassword,
  });
  assert.equal(made.statusCode, 201, made.body);
  const user = made.json().user;
  const login = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    payload: { email: user.email, password: staffPassword },
  });
  const workerToken = login.json().token;
  const body = {
    name: "Bác sĩ mới",
    email: "edited-worker@test.local",
    role: "VET",
    code: user.code,
  };
  assert.equal(
    (await sendNew("PATCH", `/api/users/${user.id}`, body, workerToken))
      .statusCode,
    403,
  );
  assert.equal(
    (
      await sendNew("PATCH", `/api/users/${user.id}`, {
        ...body,
        role: "ADMIN",
      })
    ).statusCode,
    403,
  );
  assert.equal(
    (
      await sendNew("PATCH", `/api/users/${user.id}`, {
        ...body,
        photoBase64: "broken",
      })
    ).statusCode,
    400,
  );
  assert.equal(
    (await pool.query("SELECT name FROM public.users WHERE id=$1", [user.id]))
      .rows[0].name,
    user.name,
  );
  const result = await sendNew("PATCH", `/api/users/${user.id}`, body);
  assert.equal(result.statusCode, 200, result.body);
  assert.equal(result.json().user.name, body.name);
  assert.equal(result.json().user.code, user.code);
  assert.equal(result.json().user.role, "VET");
  assert.equal(
    (await sendNew("GET", "/api/auth/me", undefined, workerToken)).statusCode,
    401,
  );
  const other = await app.inject({
    method: "POST",
    remoteAddress: "127.0.0.20",
    url: "/api/auth/register",
    payload: {
      name: "Chủ khác",
      farmName: "Trại khác",
      email: "edit-other@test.local",
      password: staffPassword,
    },
  });
  assert.equal(other.statusCode, 201, other.body);
  assert.equal(
    (await sendNew("PATCH", `/api/users/${user.id}`, body, other.json().token))
      .statusCode,
    404,
  );
});

test("deleting vet and accountant keeps clinical and finance history and cannot cross farms", async () => {
  for (const [email, token, table] of [
    ["vet@test.local", vetToken, "health_records"],
    ["accountant@test.local", accountantToken, "finance_audit"],
  ] as const) {
    const id = (
      await pool.query("SELECT id FROM public.users WHERE email=$1", [email])
    ).rows[0].id;
    const records = await pool.query(
      `SELECT * FROM ${table} WHERE actor_id=$1 ORDER BY id`,
      [id],
    );
    assert.ok(records.rowCount);
    const stranger = await app.inject({
      method: "POST",
      url: "/api/auth/register",
      remoteAddress: "127.0.0.23",
      payload: {
        name: "Chủ khác",
        farmName: "Trại xóa khác",
        email: `delete-${table}@test.local`,
        password: staffPassword,
      },
    });
    assert.equal(stranger.statusCode, 201, stranger.body);
    assert.equal(
      (
        await sendNew(
          "DELETE",
          `/api/users/${id}`,
          undefined,
          stranger.json().token,
        )
      ).statusCode,
      404,
    );
    assert.equal(
      (await sendNew("DELETE", `/api/users/${id}`, undefined, staffToken))
        .statusCode,
      403,
    );
    const removed = await sendNew("DELETE", `/api/users/${id}`);
    assert.equal(removed.statusCode, 204, removed.body);
    assert.deepEqual(
      (
        await pool.query(
          `SELECT * FROM ${table} WHERE actor_id=$1 ORDER BY id`,
          [id],
        )
      ).rows,
      records.rows,
    );
    assert.equal(
      (await sendNew("GET", "/api/auth/me", undefined, token)).statusCode,
      401,
    );
  }
});
