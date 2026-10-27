import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import sharp from "sharp";
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

async function verifyBatchCare() {
  const call = (
    method: "GET" | "POST",
    url: string,
    payload?: object,
    token = adminToken,
  ) =>
    app.inject({
      method,
      url,
      remoteAddress: "127.0.0.73",
      headers: authorization(token),
      ...(payload ? { payload } : {}),
    });
  const area = (
    await call("POST", "/api/farm/areas", { name: "Khu chăm sóc theo đợt" })
  ).json().item.id;
  const pen = (
    await call("POST", "/api/farm/pens", {
      name: "Chuồng theo đợt",
      code: "BATCH",
      areaId: area,
      capacity: 5,
    })
  ).json().item.id;
  const ids: string[] = [];
  for (let i = 0; i < 3; i++) {
    const response = await call(
      "POST",
      "/api/animals",
      animalInput(`BATCH-${i}`, pen),
    );
    assert.equal(response.statusCode, 200, response.body);
    ids.push(response.json().animal.id);
  }
  const body = {
    animalIds: [ids[0]!, ids[1]!, ids[0]!],
    kind: "VACCINATION",
    title: "Tiêm phòng theo đợt",
    dueDate: now,
    notes: "Theo dõi từng con",
    requestId: randomUUID(),
  };
  const [first, retry] = await Promise.all([
    call("POST", "/api/care-tasks/batch", body),
    call("POST", "/api/care-tasks/batch", body),
  ]);
  assert.equal(first.statusCode, 200, first.body);
  assert.equal(first.json().count, 2);
  assert.deepEqual(first.json(), retry.json());
  for (const id of ids.slice(0, 2)) {
    const detail = (await call("GET", `/api/animals/${id}`)).json();
    assert.equal(detail.careTasks.length, 1);
    assert.equal(detail.careTasks[0].title, body.title);
    assert.equal(detail.careTasks[0].actorName, "Admin");
    assert.equal(detail.careTasks[0].status, "PENDING");
  }
  assert.equal(
    (await call("GET", `/api/animals/${ids[2]}`)).json().careTasks.length,
    0,
  );
  assert.equal(
    (
      await call("POST", "/api/care-tasks/batch", {
        ...body,
        title: "Đổi nội dung cùng mã yêu cầu",
      })
    ).statusCode,
    409,
  );
  const before = (await call("GET", "/api/care-tasks")).json().total;
  for (const invalid of [
    { animalIds: [] },
    { animalIds: ["bad-id"] },
    { animalIds: Array(1001).fill(ids[0]) },
    { dueDate: "2026-02-30" },
    { requestId: undefined },
    { kind: "UNKNOWN" },
  ]) {
    assert.equal(
      (
        await call("POST", "/api/care-tasks/batch", {
          ...body,
          requestId: randomUUID(),
          ...invalid,
        })
      ).statusCode,
      400,
    );
  }
  assert.equal(
    (
      await call("POST", "/api/care-tasks/batch", {
        ...body,
        animalIds: [ids[0], randomUUID()],
        requestId: randomUUID(),
      })
    ).statusCode,
    404,
  );
  const yesterday = new Date(`${now}T00:00:00Z`);
  yesterday.setUTCDate(yesterday.getUTCDate() - 1);
  assert.equal(
    (
      await call("POST", "/api/care-tasks/batch", {
        ...body,
        dueDate: yesterday.toISOString().slice(0, 10),
        requestId: randomUUID(),
      })
    ).statusCode,
    409,
  );
  const ended = await call("POST", `/api/animals/${ids[2]}/death`, {
    date: now,
    notes: "Kiểm thử",
    requestId: randomUUID(),
  });
  assert.equal(ended.statusCode, 200, ended.body);
  assert.equal(
    (
      await call("POST", "/api/care-tasks/batch", {
        ...body,
        animalIds: [ids[0], ids[2]],
        requestId: randomUUID(),
      })
    ).statusCode,
    409,
  );
  assert.equal((await call("GET", "/api/care-tasks")).json().total, before);
  for (const role of ["STAFF", "VET", "ACCOUNTANT"]) {
    const email = `batch-${role.toLowerCase()}@test.local`;
    const created = await call("POST", "/api/users", {
      name: role,
      email,
      password: staffPassword,
      role,
    });
    assert.equal(created.statusCode, 201, created.body);
    const token = (
      await call("POST", "/api/auth/login", { email, password: staffPassword })
    ).json().token;
    const response = await call(
      "POST",
      "/api/care-tasks/batch",
      { ...body, requestId: randomUUID() },
      token,
    );
    assert.equal(
      response.statusCode,
      role === "ACCOUNTANT" ? 403 : 200,
      response.body,
    );
    if (role === "STAFF") {
      assert.equal(
        (
          await call(
            "POST",
            `/api/care-tasks/${response.json().tasks[0].id}/complete`,
            { date: now, status: "NORMAL", notes: "", requestId: randomUUID() },
            token,
          )
        ).statusCode,
        403,
      );
    }
  }
  const owner = await call("POST", "/api/auth/register", {
    name: "Chủ trại khác",
    farmName: "Trại đối chứng batch",
    email: "batch-owner@test.local",
    password: staffPassword,
  });
  assert.equal(owner.statusCode, 201, owner.body);
  const otherToken = owner.json().token;
  assert.equal(
    (
      await call(
        "POST",
        "/api/care-tasks/batch",
        { ...body, requestId: randomUUID() },
        otherToken,
      )
    ).statusCode,
    404,
  );
  assert.equal(
    (await call("GET", "/api/care-tasks", undefined, otherToken)).json().total,
    0,
  );
}
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
test("empty pens can be deleted while animal and transfer history stays intact", async () => {
  const call = (
    method: "GET" | "POST" | "PATCH" | "DELETE",
    url: string,
    payload?: object,
    token = adminToken,
  ) =>
    app.inject({
      method,
      url,
      remoteAddress: "127.0.0.74",
      headers: authorization(token),
      ...(payload ? { payload } : {}),
    });
  const areaId = (
    await call("POST", "/api/farm/areas", {
      name: "Khu kiểm tra xóa chuồng",
    })
  ).json().item.id;
  const createPen = async (code: string, active = true) => {
    const response = await call("POST", "/api/farm/pens", {
      code,
      name: code,
      areaId,
      capacity: 5,
      active,
    });
    assert.equal(response.statusCode, 200, response.body);
    return response.json().item.id as string;
  };
  for (const active of [true, false]) {
    const id = await createPen(`DELETE-EMPTY-${active}`, active);
    assert.equal(
      (await call("DELETE", `/api/farm/pens/${id}`, undefined, staffToken))
        .statusCode,
      403,
    );
    assert.equal(
      (await call("DELETE", `/api/farm/pens/${id}`)).statusCode,
      200,
    );
    assert.equal(
      (await call("DELETE", `/api/farm/pens/${id}`)).statusCode,
      404,
    );
  }
  const source = await createPen("DELETE-SOURCE");
  const destination = await createPen("DELETE-DESTINATION");
  const created = await call(
    "POST",
    "/api/animals",
    animalInput("DELETE-HISTORY", source),
  );
  assert.equal(created.statusCode, 200, created.body);
  const id = created.json().animal.id;
  const blocked = await call("DELETE", `/api/farm/pens/${source}`);
  assert.equal(blocked.statusCode, 409);
  assert.match(blocked.json().error.message, /Chuồng còn vật nuôi/);
  assert.equal(
    (
      await call("POST", `/api/animals/${id}/transfer`, {
        penId: destination,
        date: now,
        notes: "Chuyển trước khi xóa",
        requestId: randomUUID(),
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (await call("DELETE", `/api/farm/pens/${source}`)).statusCode,
    200,
  );
  assert.equal(
    (await call("POST", "/api/animals", animalInput("DELETED-PEN", source)))
      .statusCode,
    409,
  );
  assert.equal(
    (
      await call("PATCH", `/api/farm/pens/${source}`, {
        code: "DELETE-SOURCE",
        name: "Không khôi phục",
        areaId,
        capacity: 5,
        active: true,
      })
    ).statusCode,
    404,
  );
  assert.equal(
    (
      await call("POST", `/api/animals/${id}/death`, {
        date: now,
        notes: "Kết thúc nuôi",
        requestId: randomUUID(),
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (await call("DELETE", `/api/farm/pens/${destination}`)).statusCode,
    200,
  );
  const detail = (await call("GET", `/api/animals/${id}`)).json();
  assert.equal(detail.animal.status, "DEAD");
  assert.equal(detail.animal.penName, "DELETE-DESTINATION");
  assert.equal(detail.transfers.length, 1);
  assert.equal(detail.transfers[0].fromPenName, "DELETE-SOURCE");
  assert.equal(detail.transfers[0].toPenName, "DELETE-DESTINATION");
  const catalogs = (await call("GET", "/api/farm/catalogs")).json();
  assert.equal(
    catalogs.pens.some((p: { areaId: string }) => p.areaId === areaId),
    false,
  );
  const animals = (
    await call("GET", "/api/animals?status=DEAD&search=DELETE-HISTORY")
  ).json();
  assert.equal(animals.total, 1);
  assert.equal(animals.animals[0].id, id);
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
  assert.equal(pen.speciesNames.length, 1);
  const dashboardPen = (await send("GET", "/api/farm/dashboard"))
    .json()
    .pens.find((p: { id: string }) => p.id === penId);
  assert.deepEqual(dashboardPen.speciesNames, pen.speciesNames);
  assert.equal(dashboardPen.occupied, 1);
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
  assert.deepEqual(pen.speciesNames, []);
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

test(
  "batch care creates independent schedules atomically, retries safely and enforces roles and farm isolation",
  verifyBatchCare,
);

test("batch transfers preserve capacity and per-animal history atomically, enforce permissions and retry safely", async () => {
  const call = (
    method: "GET" | "POST",
    url: string,
    payload?: object,
    token = adminToken,
  ) =>
    app.inject({
      method,
      url,
      remoteAddress: "127.0.0.74",
      headers: authorization(token),
      ...(payload ? { payload } : {}),
    });
  const area = (
    await call("POST", "/api/farm/areas", { name: "Khu chuyển theo đợt" })
  ).json().item.id;
  const createPen = async (code: string, capacity: number, active = true) => {
    const response = await call("POST", "/api/farm/pens", {
      name: code,
      code,
      areaId: area,
      capacity,
      active,
    });
    assert.equal(response.statusCode, 200, response.body);
    return response.json().item.id as string;
  };
  const source = await createPen("BTSOURCE", 10),
    target = await createPen("BTTARGET", 3),
    small = await createPen("BTSMALL", 1),
    race = await createPen("BTRACE", 2),
    inactive = await createPen("BTINACTIVE", 10, false);
  const earlier = new Date(`${now}T00:00:00Z`);
  earlier.setUTCDate(earlier.getUTCDate() - 10);
  const ids: string[] = [];
  for (let i = 0; i < 5; i++) {
    const response = await call("POST", "/api/animals", {
      ...animalInput(`TRANSFER-BATCH-${i}`, i === 2 ? target : source),
      arrivalDate: earlier.toISOString().slice(0, 10),
    });
    assert.equal(response.statusCode, 200, response.body);
    ids.push(response.json().animal.id);
  }
  const body = {
    animalIds: [ids[0], ids[1], ids[0], ids[2]],
    penId: target,
    date: now,
    notes: "Chuyển theo đợt",
    requestId: randomUUID(),
  };
  const [first, repeated] = await Promise.all([
    call("POST", "/api/animals/batch/transfer", body),
    call("POST", "/api/animals/batch/transfer", body),
  ]);
  assert.equal(first.statusCode, 200, first.body);
  assert.deepEqual(first.json(), { count: 2, unchangedCount: 1 });
  assert.deepEqual(repeated.json(), first.json());
  for (const id of ids.slice(0, 3)) {
    const detail = (await call("GET", `/api/animals/${id}`)).json();
    assert.equal(detail.animal.penId, target);
    assert.equal(detail.transfers.length, id === ids[2] ? 0 : 1);
    if (detail.transfers.length) {
      assert.equal(detail.transfers[0].notes, body.notes);
      assert.equal(detail.transfers[0].actorName, "Admin");
    }
  }
  assert.equal(
    (
      await call("POST", "/api/animals/batch/transfer", {
        ...body,
        penId: source,
      })
    ).statusCode,
    409,
  );
  const yesterday = new Date(`${now}T00:00:00Z`);
  yesterday.setUTCDate(yesterday.getUTCDate() - 1);
  const tomorrow = new Date(`${now}T00:00:00Z`);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  for (const invalid of [
    { penId: small },
    { penId: inactive },
    { penId: randomUUID() },
    { penId: target },
    { penId: source, date: yesterday.toISOString().slice(0, 10) },
    { penId: source, date: tomorrow.toISOString().slice(0, 10) },
  ]) {
    const response = await call("POST", "/api/animals/batch/transfer", {
      ...body,
      requestId: randomUUID(),
      ...invalid,
    });
    assert.equal(response.statusCode, 409, response.body);
    for (const id of ids.slice(0, 2)) {
      const detail = (await call("GET", `/api/animals/${id}`)).json();
      assert.equal(detail.animal.penId, target);
      assert.equal(detail.transfers.length, 1);
    }
  }
  assert.equal(
    (
      await call("POST", "/api/animals/batch/transfer", {
        ...body,
        animalIds: [ids[0], randomUUID()],
        penId: source,
        requestId: randomUUID(),
      })
    ).statusCode,
    404,
  );
  const death = await call("POST", `/api/animals/${ids[4]}/death`, {
    date: now,
    notes: "Kiểm thử",
    requestId: randomUUID(),
  });
  assert.equal(death.statusCode, 200, death.body);
  assert.equal(
    (
      await call("POST", "/api/animals/batch/transfer", {
        ...body,
        animalIds: [ids[0], ids[4]],
        penId: source,
        requestId: randomUUID(),
      })
    ).statusCode,
    409,
  );
  for (const invalid of [
    { animalIds: [] },
    { animalIds: Array(1001).fill(ids[0]) },
    { date: "2026-02-30" },
    { requestId: undefined },
  ]) {
    assert.equal(
      (
        await call("POST", "/api/animals/batch/transfer", {
          ...body,
          ...invalid,
        })
      ).statusCode,
      400,
    );
  }
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: "/api/animals/batch/transfer",
        payload: body,
      })
    ).statusCode,
    401,
  );
  for (const role of ["STAFF", "VET", "ACCOUNTANT"]) {
    const login = await call("POST", "/api/auth/login", {
      email: `batch-${role.toLowerCase()}@test.local`,
      password: staffPassword,
    });
    assert.equal(login.statusCode, 200, login.body);
    const response = await call(
      "POST",
      "/api/animals/batch/transfer",
      { ...body, animalIds: [ids[2]], penId: source, requestId: randomUUID() },
      login.json().token,
    );
    assert.equal(
      response.statusCode,
      role === "STAFF" ? 200 : 403,
      response.body,
    );
  }
  const owner = await call("POST", "/api/auth/login", {
    email: "batch-owner@test.local",
    password: staffPassword,
  });
  assert.equal(owner.statusCode, 200, owner.body);
  assert.equal(
    (
      await call(
        "POST",
        "/api/animals/batch/transfer",
        { ...body, penId: source, requestId: randomUUID() },
        owner.json().token,
      )
    ).statusCode,
    404,
  );
  const concurrent = await Promise.all([
    call("POST", "/api/animals/batch/transfer", {
      ...body,
      animalIds: ids.slice(0, 2),
      penId: race,
      requestId: randomUUID(),
    }),
    call("POST", `/api/animals/${ids[3]}/transfer`, {
      penId: race,
      date: now,
      notes: "Cạnh tranh chỗ",
      requestId: randomUUID(),
    }),
  ]);
  assert.deepEqual(concurrent.map((r) => r.statusCode).sort(), [200, 409]);
  const residents = (await call("GET", `/api/animals?penId=${race}`)).json()
    .total;
  assert.ok(residents > 0 && residents <= 2);
});

test("batch animal intake creates numbered profiles atomically, retries safely, and enforces capacity and farm permissions", async () => {
  const call = (
    method: "GET" | "POST",
    url: string,
    payload?: object,
    token = adminToken,
  ) =>
    app.inject({
      method,
      url,
      remoteAddress: "127.0.0.76",
      headers: authorization(token),
      ...(payload ? { payload } : {}),
    });
  const area = (
    await call("POST", "/api/farm/areas", { name: "Khu nhập theo đợt" })
  ).json().item.id;
  const species = (
    await call("POST", "/api/farm/species", { name: "Gà nhập theo đợt" })
  ).json().item.id;
  const breed = (
    await call("POST", "/api/farm/breeds", {
      name: "Gà ri nhập đàn",
      speciesId: species,
    })
  ).json().item.id;
  const createPen = async (code: string, capacity: number, active = true) => {
    const r = await call("POST", "/api/farm/pens", {
      code,
      name: code,
      areaId: area,
      capacity,
      active,
    });
    assert.equal(r.statusCode, 200, r.body);
    return r.json().item.id as string;
  };
  const pen = await createPen("INTAKE", 100),
    full = await createPen("INTAKE-EXACT", 30),
    race = await createPen("INTAKE-RACE", 5),
    inactive = await createPen("INTAKE-OFF", 100);
  // Use a separate inactive, empty pen without changing any resident pen.
  const inactivePen = await createPen("INTAKE-INACTIVE", 100, false);
  const body = {
    ...animalInput("unused", pen),
    breedId: breed,
    code: undefined,
    firstCode: "GA-085",
    quantity: 30,
    name: "Gà đợt mới",
    notes: "Nhập 30 con cùng đợt",
    requestId: randomUUID(),
  };
  const [first, repeated] = await Promise.all([
    call("POST", "/api/animals/batch/create", body),
    call("POST", "/api/animals/batch/create", body),
  ]);
  assert.equal(first.statusCode, 200, first.body);
  assert.deepEqual(repeated.json(), first.json());
  assert.equal(first.json().count, 30);
  assert.equal(first.json().firstCode, "GA-085");
  assert.equal(first.json().lastCode, "GA-114");
  const profiles = (
    await call("GET", `/api/animals?penId=${pen}&pageSize=100`)
  ).json();
  assert.equal(profiles.total, 30);
  assert.equal(
    new Set(profiles.animals.map((a: { code: string }) => a.code)).size,
    30,
  );
  for (const a of profiles.animals) {
    assert.equal(a.penId, pen);
    assert.equal(a.breedId, breed);
    assert.equal(a.name, body.name);
    assert.equal(a.gender, body.gender);
    assert.equal(a.arrivalDate, body.arrivalDate);
    assert.equal(a.notes, body.notes);
    assert.equal(a.status, "ACTIVE");
    assert.equal(a.healthStatus, "NORMAL");
  }
  const countIn = async (id: string) =>
    (await call("GET", `/api/animals?penId=${id}`)).json().total;
  assert.equal(
    (await call("POST", "/api/animals/batch/create", { ...body, quantity: 31 }))
      .statusCode,
    409,
  );
  for (const invalid of [
    { firstCode: "GA-080", quantity: 10 }, // A collision inside the range must roll back every profile.
    { firstCode: "ga-085" },
    { firstCode: "NEW-001", quantity: 71 },
    { penId: inactivePen },
    { penId: randomUUID() },
    { breedId: randomUUID() },
    { birthDate: "2100-01-01" },
    { arrivalDate: "2100-01-01" },
  ]) {
    const response = await call("POST", "/api/animals/batch/create", {
      ...body,
      requestId: randomUUID(),
      ...invalid,
    });
    assert.ok([404, 409].includes(response.statusCode), response.body);
    assert.equal(await countIn(pen), 30);
  }
  for (const invalid of [
    { quantity: 0 },
    { quantity: 1.5 },
    { quantity: 1001 },
    { requestId: undefined },
    { firstCode: "NO-SUFFIX" },
    { firstCode: "X999999999999", quantity: 2 },
    { firstCode: "X1234567890123" },
    { firstCode: "X".repeat(99) + "9", quantity: 2 },
    { arrivalDate: "2026-02-30" },
    { code: "unexpected" },
  ]) {
    const response = await call("POST", "/api/animals/batch/create", {
      ...body,
      requestId: randomUUID(),
      ...invalid,
    });
    assert.equal(response.statusCode, 400, response.body);
    assert.equal(await countIn(pen), 30);
  }
  const exact = await call("POST", "/api/animals/batch/create", {
    ...body,
    firstCode: "EXACT-001",
    penId: full,
    requestId: randomUUID(),
  });
  assert.equal(exact.statusCode, 200, exact.body);
  assert.equal(await countIn(full), 30);
  assert.equal(
    (
      await call("POST", "/api/animals", {
        ...animalInput("EXACT-OVER", full),
        breedId: breed,
      })
    ).statusCode,
    409,
  );
  const concurrent = await Promise.all(
    ["A", "B"].map((prefix) =>
      call("POST", "/api/animals/batch/create", {
        ...body,
        firstCode: `RACE-${prefix}-001`,
        penId: race,
        quantity: 3,
        requestId: randomUUID(),
      }),
    ),
  );
  assert.deepEqual(concurrent.map((r) => r.statusCode).sort(), [200, 409]);
  assert.equal(await countIn(race), 3);
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: "/api/animals/batch/create",
        payload: body,
      })
    ).statusCode,
    401,
  );
  for (const role of ["staff", "vet", "accountant"]) {
    const token = (
      await call("POST", "/api/auth/login", {
        email: `batch-${role}@test.local`,
        password: staffPassword,
      })
    ).json().token;
    const response = await call(
      "POST",
      "/api/animals/batch/create",
      {
        ...body,
        firstCode: `ROLE-${role}-001`,
        quantity: 1,
        requestId: randomUUID(),
      },
      token,
    );
    assert.equal(
      response.statusCode,
      role === "staff" ? 200 : 403,
      response.body,
    );
  }
  const ownerToken = (
    await call("POST", "/api/auth/login", {
      email: "batch-owner@test.local",
      password: staffPassword,
    })
  ).json().token;
  const foreign = await call(
    "POST",
    "/api/animals/batch/create",
    { ...body, requestId: randomUUID() },
    ownerToken,
  );
  assert.equal(foreign.statusCode, 409, foreign.body);
  const foreignArea = (
    await call(
      "POST",
      "/api/farm/areas",
      { name: "Khu nhập riêng" },
      ownerToken,
    )
  ).json().item.id;
  const foreignPen = (
    await call(
      "POST",
      "/api/farm/pens",
      {
        name: "Chuồng nhập riêng",
        code: "OWN-INTAKE",
        areaId: foreignArea,
        capacity: 50,
      },
      ownerToken,
    )
  ).json().item.id;
  const foreignBreed = await call(
    "POST",
    "/api/animals/batch/create",
    { ...body, penId: foreignPen, requestId: randomUUID() },
    ownerToken,
  );
  assert.equal(foreignBreed.statusCode, 404, foreignBreed.body);
  const maximum = await createPen("INTAKE-MAXIMUM", 1000);
  const maxResponse = await call("POST", "/api/animals/batch/create", {
    ...body,
    firstCode: "MAX-000001",
    penId: maximum,
    quantity: 1000,
    requestId: randomUUID(),
  });
  assert.equal(maxResponse.statusCode, 200, maxResponse.body);
  assert.equal(maxResponse.json().count, 1000);
  assert.equal(maxResponse.json().lastCode, "MAX-001000");
  assert.equal(await countIn(maximum), 1000);
  assert.equal(await countIn(inactive), 0);
});

test("pen icons persist presets and transparent uploads, preserve omitted values and stay farm-scoped", async () => {
  const call = (
    method: "GET" | "POST" | "PATCH",
    url: string,
    payload?: object,
    token = adminToken,
  ) =>
    app.inject({
      method,
      url,
      remoteAddress: "127.0.0.75",
      headers: authorization(token),
      ...(payload ? { payload } : {}),
    });
  const area = (
    await call("POST", "/api/farm/areas", { name: "Khu icon" })
  ).json().item.id;
  const body = {
    code: "ICON-PEN",
    name: "Chuồng icon",
    areaId: area,
    capacity: 5,
    active: true,
  };
  const created = await call("POST", "/api/farm/pens", {
    ...body,
    iconKey: "fish",
  });
  assert.equal(created.statusCode, 200, created.body);
  const id = created.json().item.id;
  const pen = async () =>
    (await call("GET", "/api/farm/catalogs"))
      .json()
      .pens.find((p: { id: string }) => p.id === id);
  assert.equal((await pen()).iconKey, "fish");
  assert.equal((await pen()).iconData, null);
  const png = await sharp({
    create: {
      width: 20,
      height: 10,
      channels: 4,
      background: { r: 50, g: 120, b: 70, alpha: 0.5 },
    },
  })
    .png()
    .toBuffer();
  const uploaded = await call("PATCH", `/api/farm/pens/${id}`, {
    ...body,
    iconKey: "custom",
    iconBase64: png.toString("base64"),
  });
  assert.equal(uploaded.statusCode, 200, uploaded.body);
  const saved = await pen();
  assert.equal(saved.iconKey, "custom");
  assert.ok(saved.iconData.startsWith("data:image/png;base64,"));
  const dashboard = (await call("GET", "/api/farm/dashboard"))
    .json()
    .pens.find((p: { id: string }) => p.id === id);
  assert.equal(dashboard.iconData, saved.iconData);
  for (const payload of [body, { ...body, iconKey: "custom" }]) {
    assert.equal(
      (await call("PATCH", `/api/farm/pens/${id}`, payload)).statusCode,
      200,
    );
    assert.equal((await pen()).iconData, saved.iconData);
  }
  for (const invalid of [
    { iconKey: "unknown" },
    { iconKey: "custom", iconBase64: "bad" },
    { iconKey: "custom", iconBase64: null },
    { iconBase64: png.toString("base64") },
  ]) {
    assert.equal(
      (await call("PATCH", `/api/farm/pens/${id}`, { ...body, ...invalid }))
        .statusCode,
      400,
    );
    assert.equal((await pen()).iconData, saved.iconData);
  }
  for (const iconKey of ["barn", "pig", "auto"]) {
    assert.equal(
      (await call("PATCH", `/api/farm/pens/${id}`, { ...body, iconKey }))
        .statusCode,
      200,
    );
    assert.equal((await pen()).iconKey, iconKey);
    assert.equal((await pen()).iconData, null);
  }
  assert.equal(
    (
      await call("PATCH", `/api/farm/pens/${id}`, {
        ...body,
        iconKey: "custom",
      })
    ).statusCode,
    400,
  );
  for (const role of ["staff", "vet", "accountant"]) {
    const login = await call("POST", "/api/auth/login", {
      email: `batch-${role}@test.local`,
      password: staffPassword,
    });
    assert.equal(
      (
        await call(
          "PATCH",
          `/api/farm/pens/${id}`,
          { ...body, iconKey: "rabbit" },
          login.json().token,
        )
      ).statusCode,
      403,
    );
  }
  const owner = await call("POST", "/api/auth/login", {
    email: "batch-owner@test.local",
    password: staffPassword,
  });
  assert.equal(
    (
      await call(
        "PATCH",
        `/api/farm/pens/${id}`,
        { ...body, iconKey: "rabbit" },
        owner.json().token,
      )
    ).statusCode,
    404,
  );
  const ownArea = (
    await call(
      "POST",
      "/api/farm/areas",
      { name: "Khu mới có icon" },
      owner.json().token,
    )
  ).json().item.id;
  const ownPen = await call(
    "POST",
    "/api/farm/pens",
    { ...body, areaId: ownArea, iconKey: "barn" },
    owner.json().token,
  );
  assert.equal(ownPen.statusCode, 200, ownPen.body);
  await migrate(pool);
  assert.equal((await pen()).iconKey, "auto");
});
