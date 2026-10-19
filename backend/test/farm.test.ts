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
    databaseDir = await mkdtemp(path.join(tmpdir(), "smartfarm-farm-test-"));
    const port = 55440;
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
      !path.basename(resolved).startsWith("smartfarm-farm-test-")
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
let breedId: string,
  penId: string,
  otherPen: string,
  animalId: string,
  taskId: string;
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
const animalInput = (code: string, pen = penId) => ({
  code,
  breedId,
  gender: "FEMALE",
  birthDate: null,
  arrivalDate: now,
  origin: "Demo",
  notes: "",
  penId: pen,
});
test("catalog access control, dependencies and capacity validation", async () => {
  assert.equal((await app.inject("/api/animals")).statusCode, 401);
  assert.equal(
    (await send("POST", "/api/farm/species", { name: "Dê" }, staffToken))
      .statusCode,
    403,
  );
  const species = (
    await send("POST", "/api/farm/species", { name: "Dê" })
  ).json().item.id;
  breedId = (
    await send("POST", "/api/farm/breeds", { name: "Boer", speciesId: species })
  ).json().item.id;
  const area = (await send("POST", "/api/farm/areas", { name: "Khu A" })).json()
    .item.id;
  assert.equal(
    (
      await send("POST", "/api/farm/pens", {
        code: "BAD",
        name: "Bad",
        areaId: area,
        capacity: 0,
      })
    ).statusCode,
    400,
  );
  penId = (
    await send("POST", "/api/farm/pens", {
      code: "P1",
      name: "Chuồng 1",
      areaId: area,
      capacity: 1,
    })
  ).json().item.id;
  otherPen = (
    await send("POST", "/api/farm/pens", {
      code: "P2",
      name: "Chuồng 2",
      areaId: area,
      capacity: 2,
    })
  ).json().item.id;
  assert.equal(
    (await send("DELETE", `/api/farm/species/${species}`)).statusCode,
    409,
  );
});
test("concurrent animal creation cannot exceed capacity; duplicate codes and invalid dates rejected", async () => {
  const result = await Promise.all([
    send("POST", "/api/animals", animalInput("GOAT-1"), staffToken),
    send("POST", "/api/animals", animalInput("GOAT-2")),
  ]);
  assert.deepEqual(result.map((r) => r.statusCode).sort(), [200, 409]);
  animalId = result.find((r) => r.statusCode === 200)!.json().animal.id;
  assert.equal(
    (
      await send("POST", "/api/animals", {
        ...animalInput("BAD", otherPen),
        arrivalDate: "2026-02-30",
      })
    ).statusCode,
    400,
  );
  const code = (await send("GET", `/api/animals/${animalId}`)).json().animal
    .code;
  assert.equal(
    (await send("POST", "/api/animals", animalInput(code, otherPen)))
      .statusCode,
    409,
  );
  const pen = (await send("GET", "/api/farm/catalogs"))
    .json()
    .pens.find((p: { id: string }) => p.id === penId);
  assert.equal(pen.occupied, 1);
  assert.equal(
    (
      await send("PATCH", `/api/farm/pens/${penId}`, {
        code: pen.code,
        name: pen.name,
        areaId: pen.areaId,
        capacity: 1,
        active: false,
      })
    ).statusCode,
    409,
  );
});
test("transfer and weight are idempotent and history blocks deletion", async () => {
  const b = {
    date: now,
    penId: otherPen,
    notes: "Chuyển",
    requestId: randomUUID(),
  };
  assert.equal(
    (await send("POST", `/api/animals/${animalId}/transfer`, b, staffToken))
      .statusCode,
    200,
  );
  assert.equal(
    (await send("POST", `/api/animals/${animalId}/transfer`, b, staffToken))
      .statusCode,
    200,
  );
  assert.equal(
    (
      await send(
        "POST",
        `/api/animals/${animalId}/transfer`,
        { ...b, notes: "Khác" },
        staffToken,
      )
    ).statusCode,
    409,
  );
  assert.equal(
    (
      await send("POST", `/api/animals/${animalId}/weights`, {
        date: now,
        kg: 0,
        notes: "",
        requestId: randomUUID(),
      })
    ).statusCode,
    400,
  );
  const weight = { date: now, kg: 22.5, notes: "", requestId: randomUUID() };
  assert.equal(
    (await send("POST", `/api/animals/${animalId}/weights`, weight)).statusCode,
    200,
  );
  assert.equal(
    (await send("POST", `/api/animals/${animalId}/weights`, weight)).statusCode,
    200,
  );
  const d = (await send("GET", `/api/animals/${animalId}`)).json();
  assert.equal(d.transfers.length, 1);
  assert.equal(d.weights.length, 1);
  assert.equal(d.animal.penId, otherPen);
  assert.equal(
    (await send("DELETE", `/api/animals/${animalId}`)).statusCode,
    409,
  );
  // Employee deletion with history is verified after the remaining staff workflows.
});
test("health, care completion concurrency and dashboard reflect actual data", async () => {
  const h = {
    date: now,
    content: "Kiểm tra",
    status: "NEEDS_CARE",
    notes: "",
    requestId: randomUUID(),
  };
  assert.equal(
    (await send("POST", `/api/animals/${animalId}/health`, h, staffToken))
      .statusCode,
    200,
  );
  const t = await send("POST", "/api/care-tasks", {
    animalId,
    kind: "CHECKUP",
    title: "Kiểm tra lại",
    dueDate: now,
    notes: "",
  });
  assert.equal(t.statusCode, 200);
  taskId = t.json().task.id;
  const dash = (
    await send("GET", "/api/farm/dashboard", undefined, staffToken)
  ).json();
  assert.equal(dash.needsCare, 1);
  assert.equal(dash.due, 1);
  const complete = {
    date: now,
    status: "NORMAL",
    notes: "Khỏe",
    requestId: randomUUID(),
  };
  const done = await Promise.all([
    send("POST", `/api/care-tasks/${taskId}/complete`, complete),
    send("POST", `/api/care-tasks/${taskId}/complete`, complete),
  ]);
  assert.deepEqual(
    done.map((r) => r.statusCode),
    [200, 200],
  );
  assert.equal(
    (
      await send("POST", `/api/care-tasks/${taskId}/complete`, {
        ...complete,
        requestId: randomUUID(),
      })
    ).statusCode,
    409,
  );
  const detail = (await send("GET", `/api/animals/${animalId}`)).json();
  assert.equal(detail.healthRecords.length, 2);
  assert.equal(detail.animal.healthStatus, "NORMAL");
  assert.equal(detail.careTasks[0].status, "DONE");
});
test("care edit/cancel and death preserve completed history, cancel pending and free pen", async () => {
  const t = await send("POST", "/api/care-tasks", {
    animalId,
    kind: "VACCINATION",
    title: "Tiêm",
    dueDate: now,
    notes: "",
  });
  const id = t.json().task.id;
  assert.equal(
    (
      await send(
        "PATCH",
        `/api/care-tasks/${id}`,
        { kind: "CHECKUP", title: "Kiểm tra", dueDate: now, notes: "Đã sửa" },
        staffToken,
      )
    ).statusCode,
    200,
  );
  assert.equal(
    (await send("POST", `/api/care-tasks/${id}/cancel`, undefined, staffToken))
      .statusCode,
    200,
  );
  await send("POST", "/api/care-tasks", {
    animalId,
    kind: "VACCINATION",
    title: "Tiêm mới",
    dueDate: now,
    notes: "",
  });
  const b = { date: now, notes: "Đã chết", requestId: randomUUID() };
  assert.equal(
    (await send("POST", `/api/animals/${animalId}/death`, b, staffToken))
      .statusCode,
    403,
  );
  assert.equal(
    (await send("POST", `/api/animals/${animalId}/death`, b)).statusCode,
    200,
  );
  assert.equal(
    (await send("POST", `/api/animals/${animalId}/death`, b)).statusCode,
    200,
  );
  assert.equal(
    (
      await send("POST", "/api/care-tasks", {
        animalId,
        kind: "CHECKUP",
        title: "Sai",
        dueDate: now,
        notes: "",
      })
    ).statusCode,
    409,
  );
  assert.equal(
    (
      await send("POST", `/api/animals/${animalId}/weights`, {
        date: now,
        kg: 33,
        notes: "",
        requestId: randomUUID(),
      })
    ).statusCode,
    409,
  );
  const detail = (await send("GET", `/api/animals/${animalId}`)).json();
  assert.equal(detail.animal.status, "DEAD");
  assert.equal(detail.weights.length, 1);
  assert.equal(detail.healthRecords.length, 2);
  assert.equal(
    detail.careTasks.filter((t: { status: string }) => t.status === "PENDING")
      .length,
    0,
  );
  assert.equal(
    detail.careTasks.filter((t: { status: string }) => t.status === "DONE")
      .length,
    1,
  );
  const dash = (await send("GET", "/api/farm/dashboard")).json();
  assert.equal(dash.activeAnimals, 0);
  assert.equal(dash.needsCare, 0);
  const pen = (await send("GET", "/api/farm/catalogs"))
    .json()
    .pens.find((p: { id: string }) => p.id === otherPen);
  assert.equal(pen.occupied, 0);
});
test("search pagination, species/breed consistency and deleting an unused profile", async () => {
  const result = await send("POST", "/api/animals", animalInput("TEMP-1"));
  const id = result.json().animal.id;
  const filtered = (
    await send("GET", "/api/animals?search=TEMP&pageSize=1")
  ).json();
  assert.equal(filtered.total, 1);
  assert.equal(filtered.animals[0].id, id);
  const off = (
    await send("GET", "/api/animals?search=TEMP&page=2&pageSize=1")
  ).json();
  assert.equal(off.total, 1);
  assert.equal(off.animals.length, 0);
  const otherSpecies = (
    await send("POST", "/api/farm/species", { name: "Bò" })
  ).json().item.id;
  assert.equal(
    (
      await send("PATCH", `/api/farm/breeds/${breedId}`, {
        name: "Boer",
        speciesId: otherSpecies,
      })
    ).statusCode,
    409,
  );
  const { penId: _, ...body } = animalInput("TEMP-EDIT");
  assert.equal(
    (await send("PATCH", `/api/animals/${id}`, body)).statusCode,
    200,
  );
  assert.equal(
    (await send("DELETE", `/api/animals/${id}`, undefined, staffToken))
      .statusCode,
    403,
  );
  assert.equal((await send("DELETE", `/api/animals/${id}`)).statusCode, 200);
  assert.equal((await send("GET", `/api/animals/${id}`)).statusCode, 404);
});

test("backdated health does not overwrite current status; name search and three decimal weights work", async () => {
  const old = new Date(`${now}T00:00:00Z`);
  old.setUTCDate(old.getUTCDate() - 10);
  const arrival = old.toISOString().slice(0, 10);
  old.setUTCDate(old.getUTCDate() + 2);
  const earlier = old.toISOString().slice(0, 10);
  const r = await send("POST", "/api/animals", {
    ...animalInput("PRECISION", otherPen),
    name: "Dê Bông",
    arrivalDate: arrival,
  });
  assert.equal(r.statusCode, 200);
  const id = r.json().animal.id;
  const h = (date: string, status: string) => ({
    date,
    status,
    content: "Kiểm tra",
    notes: "",
    requestId: randomUUID(),
  });
  assert.equal(
    (await send("POST", `/api/animals/${id}/health`, h(now, "NORMAL")))
      .statusCode,
    200,
  );
  assert.equal(
    (await send("POST", `/api/animals/${id}/health`, h(earlier, "NEEDS_CARE")))
      .statusCode,
    200,
  );
  const w = { date: now, kg: 22.125, notes: "", requestId: randomUUID() };
  assert.equal(
    (await send("POST", `/api/animals/${id}/weights`, w)).statusCode,
    200,
  );
  assert.equal(
    (
      await send("POST", `/api/animals/${id}/weights`, {
        ...w,
        kg: 22.1234,
        requestId: randomUUID(),
      })
    ).statusCode,
    400,
  );
  const future = new Date(`${now}T00:00:00Z`);
  future.setUTCDate(future.getUTCDate() + 1);
  assert.equal(
    (
      await send(
        "POST",
        `/api/animals/${id}/health`,
        h(future.toISOString().slice(0, 10), "NORMAL"),
      )
    ).statusCode,
    409,
  );
  const detail = (await send("GET", `/api/animals/${id}`)).json();
  assert.equal(detail.animal.healthStatus, "NORMAL");
  assert.equal(detail.weights[0].kg, 22.125);
  const found = (
    await send("GET", `/api/animals?search=${encodeURIComponent("Bông")}`)
  ).json();
  assert.equal(found.animals[0].id, id);
});

test("deleting employee with history preserves audit, removes access and releases email", async () => {
  const call = (
    method: "GET" | "POST" | "PATCH" | "DELETE",
    url: string,
    payload?: object,
    token = adminToken,
  ) =>
    app.inject({
      method,
      url,
      remoteAddress: "127.0.0.22",
      headers: authorization(token),
      ...(payload ? { payload } : {}),
    });
  const before = (await call("GET", `/api/animals/${animalId}`)).json();
  assert.ok(
    before.healthRecords.some(
      (r: { actorName: string }) => r.actorName === "Staff",
    ),
  );
  const result = await call("DELETE", `/api/users/${staffId}`);
  assert.equal(result.statusCode, 204, result.body);
  const deleted = (
    await pool.query(
      "SELECT active,deleted_at,email,password_hash,avatar_data FROM public.users WHERE id=$1",
      [staffId],
    )
  ).rows[0];
  assert.equal(deleted.active, false);
  assert.ok(deleted.deleted_at);
  assert.notEqual(deleted.email, "staff@test.local");
  assert.equal(deleted.password_hash, "deleted");
  assert.equal(deleted.avatar_data, null);
  await assert.rejects(
    pool.query("UPDATE public.users SET active=true WHERE id=$1", [staffId]),
    (error: unknown) => (error as { code?: string }).code === "23514",
  );
  const list = await call("GET", "/api/users");
  assert.equal(list.statusCode, 200, list.body);
  assert.equal(
    list.json().users.some((u: { id: string }) => u.id === staffId),
    false,
  );
  assert.equal(
    (await call("GET", "/api/auth/me", undefined, staffToken)).statusCode,
    401,
  );
  assert.equal(
    (
      await call("POST", "/api/auth/login", {
        email: "staff@test.local",
        password: staffPassword,
      })
    ).statusCode,
    401,
  );
  assert.equal(
    (await call("PATCH", `/api/users/${staffId}/status`, { active: true }))
      .statusCode,
    404,
  );
  assert.equal(
    (await call("PATCH", `/api/users/${staffId}/avatar`, { photoBase64: null }))
      .statusCode,
    404,
  );
  assert.equal(
    (
      await call("PATCH", `/api/users/${staffId}`, {
        name: "Khôi phục",
        email: "staff@test.local",
        role: "STAFF",
      })
    ).statusCode,
    404,
  );
  assert.equal((await call("DELETE", `/api/users/${staffId}`)).statusCode, 404);
  const after = (await call("GET", `/api/animals/${animalId}`)).json();
  assert.deepEqual(after.healthRecords, before.healthRecords);
  assert.deepEqual(after.weights, before.weights);
  assert.deepEqual(after.transfers, before.transfers);
  await migrate(pool);
  await migrate(pool);
  const recreated = await call("POST", "/api/users", {
    name: "Nhân viên mới",
    email: "staff@test.local",
    password: staffPassword,
  });
  assert.equal(recreated.statusCode, 201, recreated.body);
  assert.notEqual(recreated.json().user.id, staffId);
});
