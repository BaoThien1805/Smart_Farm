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
    databaseDir = await mkdtemp(path.join(tmpdir(), "smartfarm-test-"));
    const port = 55439;
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
      !path.basename(resolved).startsWith("smartfarm-test-")
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

test("reject missing authentication and incorrect credentials without leaking account existence", async () => {
  assert.equal((await app.inject("/api/auth/me")).statusCode, 401);
  const bad = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    payload: { email: "admin@test.local", password: "bad" },
  });
  const missing = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    payload: { email: "nobody@test.local", password: "bad" },
  });
  assert.equal(bad.statusCode, 401);
  assert.deepEqual(bad.json(), missing.json());
});
test("login stores only hashed token, profile never returns password hash", async () => {
  const response = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    payload: { email: "ADMIN@test.local", password: adminPassword },
  });
  assert.equal(response.statusCode, 200);
  adminToken = response.json().token;
  assert.equal(response.json().user.password_hash, undefined);
  const sessions = await pool.query("SELECT token_hash FROM sessions");
  assert.equal(sessions.rows[0].token_hash, tokenHash(adminToken));
  assert.notEqual(sessions.rows[0].token_hash, adminToken);
  assert.equal(
    (
      await app.inject({
        url: "/api/auth/me",
        headers: authorization(adminToken),
      })
    ).json().user.role,
    "ADMIN",
  );
});
test("admin creates STAFF; validation rejects privilege injection, duplicate email, short password", async () => {
  const create = (payload: unknown) =>
    app.inject({
      method: "POST",
      url: "/api/users",
      headers: authorization(adminToken),
      payload: payload as Record<string, string>,
    });
  const input = {
    name: "Nhân viên",
    email: "staff@test.local",
    password: staffPassword,
  };
  assert.equal((await create({ ...input, role: "ADMIN" })).statusCode, 400);
  assert.equal((await create({ ...input, password: "short" })).statusCode, 400);
  const response = await create(input);
  assert.equal(response.statusCode, 201);
  staffId = response.json().user.id;
  assert.equal(response.json().user.role, "STAFF");
  assert.equal(
    (await create({ ...input, email: "STAFF@test.local" })).statusCode,
    409,
  );
});
test("STAFF is denied direct admin API access and lists are paginated", async () => {
  const response = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    payload: { email: "staff@test.local", password: staffPassword },
  });
  staffToken = response.json().token;
  for (const request of [
    { method: "GET" as const, url: "/api/users" },
    {
      method: "POST" as const,
      url: "/api/users",
      payload: {
        name: "Other",
        email: "other@test.local",
        password: staffPassword,
      },
    },
    {
      method: "PATCH" as const,
      url: `/api/users/${staffId}/status`,
      payload: { active: false },
    },
    { method: "DELETE" as const, url: `/api/users/${staffId}` },
  ])
    assert.equal(
      (await app.inject({ ...request, headers: authorization(staffToken) }))
        .statusCode,
      403,
    );
  const list = await app.inject({
    url: "/api/users?pageSize=1",
    headers: authorization(adminToken),
  });
  assert.equal(list.json().users.length, 1);
  assert.equal(list.json().total, 2);
  assert.equal(list.body.includes("password_hash"), false);
});
test("locking revokes existing sessions; unlocking never restores them; admin cannot be locked", async () => {
  const status = (active: boolean) =>
    app.inject({
      method: "PATCH",
      url: `/api/users/${staffId}/status`,
      headers: authorization(adminToken),
      payload: { active },
    });
  assert.equal((await status(false)).statusCode, 200);
  assert.equal(
    (
      await app.inject({
        url: "/api/auth/me",
        headers: authorization(staffToken),
      })
    ).statusCode,
    401,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: "/api/auth/login",
        payload: { email: "staff@test.local", password: staffPassword },
      })
    ).statusCode,
    401,
  );
  await status(true);
  assert.equal(
    (
      await app.inject({
        url: "/api/auth/me",
        headers: authorization(staffToken),
      })
    ).statusCode,
    401,
  );
  const adminId = (
    await app.inject({
      url: "/api/auth/me",
      headers: authorization(adminToken),
    })
  ).json().user.id;
  assert.equal(
    (
      await app.inject({
        method: "PATCH",
        url: `/api/users/${adminId}/status`,
        headers: authorization(adminToken),
        payload: { active: false },
      })
    ).statusCode,
    403,
  );
});
test("deleting staff removes user; admin cannot delete admin", async () => {
  // Admin cannot delete admin
  const adminId = (
    await app.inject({
      url: "/api/auth/me",
      headers: authorization(adminToken),
    })
  ).json().user.id;
  assert.equal(
    (
      await app.inject({
        method: "DELETE",
        url: `/api/users/${adminId}`,
        headers: authorization(adminToken),
      })
    ).statusCode,
    403,
  );

  // Admin creates a temporary staff and deletes it
  const created = await app.inject({
    method: "POST",
    url: "/api/users",
    headers: authorization(adminToken),
    payload: {
      name: "To Delete",
      email: "todelete@test.local",
      password: staffPassword,
    },
  });
  const deleteId = created.json().user.id;
  const session = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    payload: { email: "todelete@test.local", password: staffPassword },
  });
  assert.equal(session.statusCode, 200);
  const deletedToken = session.json().token;

  assert.equal(
    (
      await app.inject({
        method: "DELETE",
        url: `/api/users/${deleteId}`,
        headers: authorization(adminToken),
      })
    ).statusCode,
    204,
  );

  // Deleting again returns 404
  assert.equal(
    (
      await app.inject({
        url: "/api/auth/me",
        headers: authorization(deletedToken),
      })
    ).statusCode,
    401,
  );
  const list = (
    await app.inject({ url: "/api/users", headers: authorization(adminToken) })
  ).json();
  assert.equal(
    list.users.some((user: { id: string }) => user.id === deleteId),
    false,
  );
  assert.equal(
    (
      await app.inject({
        method: "DELETE",
        url: `/api/users/${deleteId}`,
        headers: authorization(adminToken),
      })
    ).statusCode,
    404,
  );
});
test("changing password revokes all user sessions and rejects old credentials", async () => {
  const login = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    payload: { email: "staff@test.local", password: staffPassword },
  });
  staffToken = login.json().token;
  const change = (currentPassword: string) =>
    app.inject({
      method: "POST",
      url: "/api/auth/password",
      headers: authorization(staffToken),
      payload: { currentPassword, newPassword: "New-staff-password-99" },
    });
  assert.equal((await change("wrong")).statusCode, 400);
  assert.equal((await change(staffPassword)).statusCode, 204);
  assert.equal(
    (
      await app.inject({
        url: "/api/auth/me",
        headers: authorization(staffToken),
      })
    ).statusCode,
    401,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: "/api/auth/login",
        payload: { email: "staff@test.local", password: staffPassword },
      })
    ).statusCode,
    401,
  );
  const newLogin = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    payload: { email: "staff@test.local", password: "New-staff-password-99" },
  });
  assert.equal(newLogin.statusCode, 200);
  staffToken = newLogin.json().token;
});
test("expired sessions and logout are rejected on subsequent calls", async () => {
  await pool.query(
    "UPDATE sessions SET expires_at=now()-interval '1 second' WHERE token_hash=$1",
    [tokenHash(staffToken)],
  );
  assert.equal(
    (
      await app.inject({
        url: "/api/auth/me",
        headers: authorization(staffToken),
      })
    ).statusCode,
    401,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: "/api/auth/logout",
        headers: authorization(adminToken),
      })
    ).statusCode,
    204,
  );
  assert.equal(
    (
      await app.inject({
        url: "/api/users",
        headers: authorization(adminToken),
      })
    ).statusCode,
    401,
  );
});
test("CORS only permits configured origins and login rate limit is active", async () => {
  const cors = await app.inject({
    url: "/api/health",
    headers: { origin: "https://untrusted.example" },
  });
  assert.equal(cors.headers["access-control-allow-origin"], undefined);
  let last = 0;
  for (let i = 0; i < 11; i++)
    last = (
      await app.inject({
        method: "POST",
        url: "/api/auth/login",
        payload: { email: "invalid@test.local", password: "bad" },
      })
    ).statusCode;
  assert.equal(last, 429);
});

test("owner registration creates isolated farms and scopes staff management", async () => {
  const register = (email: string, extra: Record<string, unknown> = {}) =>
    app.inject({
      method: "POST",
      url: "/api/auth/register",
      remoteAddress: "198.51.100.28",
      payload: {
        name: "Chủ trang trại",
        farmName: "Trang trại mới",
        email,
        password: "Owner-test-password-42",
        ...extra,
      },
    });
  const a = await register("owner-a@test.local");
  const b = await register("owner-b@test.local");
  assert.equal(a.statusCode, 201, a.body);
  assert.equal(b.statusCode, 201, b.body);
  assert.notEqual(a.json().user.farmId, b.json().user.farmId);
  assert.equal(a.json().user.role, "ADMIN");
  assert.equal(a.body.includes("password_hash"), false);
  assert.equal((await register("owner-a@test.local")).statusCode, 409);
  assert.equal(
    (await register("owner-injected@test.local", { role: "ADMIN" })).statusCode,
    400,
  );
  assert.equal(
    (await register("owner-short@test.local", { password: "short" }))
      .statusCode,
    400,
  );
  const legacyLogin = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    remoteAddress: "198.51.100.29",
    payload: { email: "admin@test.local", password: adminPassword },
  });
  assert.equal(legacyLogin.statusCode, 200, legacyLogin.body);
  adminToken = legacyLogin.json().token;
  const tokenA = a.json().token,
    tokenB = b.json().token;
  const call = (
    token: string,
    method: "GET" | "POST" | "PATCH" | "DELETE",
    url: string,
    payload?: Record<string, unknown>,
  ) =>
    app.inject({
      method,
      url,
      headers: authorization(token),
      ...(payload ? { payload } : {}),
    });
  const catalogs = await call(tokenA, "GET", "/api/farm/catalogs");
  assert.equal(catalogs.statusCode, 200, catalogs.body);
  assert.equal(catalogs.json().species.length, 12);
  const speciesA = catalogs.json().species[0].id;
  assert.equal(
    (
      await call(tokenB, "PATCH", `/api/farm/species/${speciesA}`, {
        name: "Không được sửa",
      })
    ).statusCode,
    404,
  );
  const created = await call(tokenA, "POST", "/api/feeds", {
    code: "ONLY-A",
    name: "Cám trang trại A",
    lowStock: 0,
    active: true,
    notes: "",
  });
  assert.equal(created.statusCode, 200, created.body);
  const feedId = created.json().feed.id;
  const [feedsA, feedsB, feedsLegacy] = await Promise.all([
    call(tokenA, "GET", "/api/feeds"),
    call(tokenB, "GET", "/api/feeds"),
    call(adminToken, "GET", "/api/feeds"),
  ]);
  assert.equal(feedsA.json().feeds.length, 1);
  assert.equal(feedsB.json().feeds.length, 0);
  assert.equal(
    feedsLegacy.json().feeds.some((f: { id: string }) => f.id === feedId),
    false,
  );
  assert.equal(
    (
      await call(tokenB, "PATCH", `/api/feeds/${feedId}`, {
        code: "HACK",
        name: "Cám khác",
        lowStock: 0,
        active: true,
        notes: "",
      })
    ).statusCode,
    404,
  );
  assert.equal(
    (
      await call(tokenB, "PATCH", "/api/farm/preferences", {
        speciesIds: [speciesA],
      })
    ).statusCode,
    409,
  );
  const area = await call(tokenA, "POST", "/api/farm/areas", { name: "Khu A" });
  assert.equal(area.statusCode, 200, area.body);
  const breed = await call(tokenA, "POST", "/api/farm/breeds", {
    name: "Giống A",
    speciesId: speciesA,
  });
  assert.equal(breed.statusCode, 200, breed.body);
  const pen = await call(tokenA, "POST", "/api/farm/pens", {
    code: "A1",
    name: "Chuồng A",
    areaId: area.json().item.id,
    capacity: 10,
    active: true,
  });
  assert.equal(pen.statusCode, 200, pen.body);
  const animalBody = {
    code: "ANIMAL-A",
    breedId: breed.json().item.id,
    gender: "FEMALE",
    arrivalDate: "2026-01-01",
    penId: pen.json().item.id,
  };
  const animal = await call(tokenA, "POST", "/api/animals", animalBody);
  assert.equal(animal.statusCode, 200, animal.body);
  const animalId = animal.json().animal.id;
  assert.equal(
    (await call(tokenA, "GET", `/api/animals/${animalId}`)).statusCode,
    200,
  );
  assert.equal(
    (await call(tokenB, "GET", `/api/animals/${animalId}`)).statusCode,
    404,
  );
  assert.equal(
    (await call(tokenB, "POST", "/api/animals", animalBody)).statusCode,
    409,
  );
  const lists = await Promise.all(
    Array.from({ length: 10 }, (_, i) =>
      call(i % 2 === 0 ? tokenA : tokenB, "GET", "/api/animals"),
    ),
  );
  lists.forEach((r, i) =>
    assert.equal(r.json().total, i % 2 === 0 ? 1 : 0, r.body),
  );
  const employee = await call(tokenA, "POST", "/api/users", {
    name: "Nhân viên A",
    email: "employee-a@test.local",
    password: "Employee-test-password-42",
  });
  assert.equal(employee.statusCode, 201, employee.body);
  const employeeId = employee.json().user.id;
  const listB = await call(tokenB, "GET", "/api/users");
  assert.equal(listB.json().total, 1);
  assert.equal(
    (
      await call(tokenB, "PATCH", `/api/users/${employeeId}/status`, {
        active: false,
      })
    ).statusCode,
    404,
  );
  assert.equal(
    (await call(tokenB, "DELETE", `/api/users/${employeeId}`)).statusCode,
    404,
  );
  const login = await app.inject({
    remoteAddress: "198.51.100.29",
    method: "POST",
    url: "/api/auth/login",
    payload: {
      email: "employee-a@test.local",
      password: "Employee-test-password-42",
    },
  });
  assert.equal(login.statusCode, 200, login.body);
  assert.equal(
    (await call(login.json().token, "GET", "/api/feeds")).json().feeds[0].id,
    feedId,
  );
  assert.equal(
    (
      await call(login.json().token, "POST", "/api/feeds", {
        code: "DENIED",
        name: "Thức ăn",
        lowStock: 0,
      })
    ).statusCode,
    403,
  );
  // Pool connections must not retain a tenant search_path after requests.
  assert.equal(
    (await app.inject({ method: "GET", url: "/api/weather" })).statusCode,
    401,
  );
  assert.equal((await call(tokenA, "GET", "/api/weather")).statusCode, 409);
  assert.equal(
    (
      await call(tokenA, "PATCH", "/api/farm/location", {
        latitude: 91,
        longitude: 106,
      })
    ).statusCode,
    400,
  );
  assert.equal(
    (
      await call(tokenA, "PATCH", "/api/farm/location", {
        latitude: 10.8,
        longitude: 106.6,
        farmId: "injected",
      })
    ).statusCode,
    400,
  );
  assert.equal(
    (
      await call(tokenA, "PATCH", "/api/farm/location", {
        latitude: 10.8,
        longitude: 106.6,
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (await call(tokenA, "GET", "/api/farm/location")).json().location.latitude,
    10.8,
  );
  assert.equal(
    (await call(tokenB, "GET", "/api/farm/location")).json().location.latitude,
    null,
  );
  assert.equal(
    (await call(login.json().token, "GET", "/api/farm/location")).json()
      .location.latitude,
    10.8,
  );
  assert.equal(
    (
      await call(login.json().token, "PATCH", "/api/farm/location", {
        latitude: 20,
        longitude: 100,
      })
    ).statusCode,
    403,
  );
  assert.equal((await call(tokenA, "GET", "/api/weather")).statusCode, 503);
  const path = await pool.query("SHOW search_path");
  assert.equal(path.rows[0].search_path, '"$user", public');
});
