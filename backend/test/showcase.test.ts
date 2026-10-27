import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import type { Pool } from "pg";
import type { FastifyInstance } from "fastify";
import EmbeddedPostgres from "../support/local-postgres.js";
import { createPool, migrate } from "../src/database.js";
import { buildApp } from "../src/app.js";
import {
  seedShowcase,
  demoAccounts,
  demoPassword,
  demoFarmId,
  controlEmail,
} from "../support/showcase.js";

let databaseDir: string, pg: EmbeddedPostgres, pool: Pool, app: FastifyInstance;
before(
  async () => {
    databaseDir = await mkdtemp(
      path.join(tmpdir(), "smartfarm-showcase-test-"),
    );
    pg = new EmbeddedPostgres({
      databaseDir,
      port: 55469,
      user: "testuser",
      password: "test-only-password",
      persistent: true,
      authMethod: "scram-sha-256",
      postgresFlags: ["-h", "127.0.0.1"],
      initdbFlags: ["--encoding=UTF8", "--locale=C"],
      onLog: () => {},
      onError: () => {},
    });
    await pg.initialise();
    await pg.start();
    await pg.createDatabase("showcase_test");
    pool = createPool(
      "postgresql://testuser:test-only-password@127.0.0.1:55469/showcase_test",
    );
    await migrate(pool);
    app = await buildApp(
      pool,
      {
        DATABASE_URL: "",
        NODE_ENV: "test",
        HOST: "127.0.0.1",
        PORT: 3000,
        CORS_ORIGINS: "http://localhost:8080",
        SESSION_HOURS: 8,
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
  if (databaseDir) {
    const resolved = path.resolve(databaseDir);
    if (
      path.dirname(resolved) !== path.resolve(tmpdir()) ||
      !path.basename(resolved).startsWith("smartfarm-showcase-test-")
    )
      throw new Error("Unsafe test cleanup path");
    await rm(resolved, {
      recursive: true,
      force: true,
      maxRetries: 10,
      retryDelay: 200,
    });
  }
});
test("complete demo is usable through real role APIs, isolated and repeatable without resetting work", async () => {
  const first = await seedShowcase(pool);
  assert.equal(first.created, true);
  const tokens: Record<string, string> = {};
  for (const account of demoAccounts) {
    const response = await app.inject({
      method: "POST",
      url: "/api/auth/login",
      payload: { email: account.email, password: demoPassword },
    });
    assert.equal(
      response.statusCode,
      account.active ? 200 : 401,
      account.email,
    );
    if (account.active && !tokens[account.role])
      tokens[account.role] = response.json().token;
  }
  const get = async (role: string, url: string, status = 200) => {
    const response = await app.inject({
      method: "GET",
      url,
      headers: { authorization: `Bearer ${tokens[role]}` },
    });
    assert.equal(response.statusCode, status, url);
    return response.json();
  };
  const catalogs = await get("ADMIN", "/api/farm/catalogs");
  assert.equal(catalogs.species.length, 12);
  assert.equal(catalogs.breeds.length, 24);
  assert.equal(catalogs.pens.length, 26);
  assert.ok(
    catalogs.pens.some((p: any) => p.occupied === p.capacity && p.active),
  );
  assert.ok(catalogs.pens.some((p: any) => p.occupied === 0 && p.active));
  assert.ok(catalogs.pens.some((p: any) => !p.active));
  const all = await get("ADMIN", "/api/animals?pageSize=100");
  assert.equal(all.total, 56);
  assert.equal(
    all.animals.filter((a: any) => a.status === "ACTIVE").length,
    51,
  );
  assert.equal(all.animals.filter((a: any) => a.status === "SOLD").length, 3);
  assert.equal(all.animals.filter((a: any) => a.status === "DEAD").length, 2);
  const animal = all.animals.find((a: any) => a.code === "BO-001");
  const detail = await get("VET", "/api/animals/" + animal.id);
  assert.equal(detail.weights.length, 4);
  assert.equal(detail.transfers.length, 1);
  assert.ok(detail.healthRecords.some((h: any) => h.recordType === "EXAM"));
  assert.ok(detail.animal.imageData.startsWith("data:image/jpeg;base64,"));
  const care = await get(
    "STAFF",
    "/api/care-tasks?status=PENDING&pageSize=100",
  );
  assert.equal(care.total, 36);
  assert.ok(care.tasks.some((t: any) => t.dueDate < care.today));
  assert.ok(care.tasks.some((t: any) => t.dueDate === care.today));
  await get("STAFF", "/api/users", 403);
  await get("VET", "/api/stock-entries", 403);
  await get("STAFF", "/api/finance/report", 403);
  const denied = await app.inject({
    method: "POST",
    url: "/api/care-tasks/" + care.tasks[0].id + "/complete",
    headers: { authorization: `Bearer ${tokens.STAFF}` },
    payload: {},
  });
  assert.equal(denied.statusCode, 403);
  const report = await get("ACCOUNTANT", "/api/finance/report");
  assert.ok(Number(report.summary.income) > 0);
  const sale = await get("ACCOUNTANT", "/api/sales?status=ALL");
  assert.equal(sale.total, 4);
  assert.equal(sale.sales.filter((s: any) => s.cancelledAt).length, 1);
  const feeds = await get("STAFF", "/api/feeds");
  assert.equal(feeds.feeds.length, 8);
  assert.ok(feeds.feeds.some((f: any) => f.active && f.stock <= f.lowStock));
  const other = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    payload: { email: controlEmail, password: demoPassword },
  });
  assert.equal(other.statusCode, 200);
  const hidden = await app.inject({
    method: "GET",
    url: "/api/animals/" + animal.id,
    headers: { authorization: `Bearer ${other.json().token}` },
  });
  assert.equal(hidden.statusCode, 404);
  const otherList = await app.inject({
    method: "GET",
    url: "/api/animals",
    headers: { authorization: `Bearer ${other.json().token}` },
  });
  assert.equal(otherList.json().total, 1);
  assert.equal(otherList.json().animals[0].code, "DC-001");
  const schema = "farm_" + demoFarmId.replaceAll("-", "");
  await pool.query(
    `UPDATE ${schema}.animals SET notes='Thao tác người dùng cần giữ' WHERE id=$1`,
    [animal.id],
  );
  await pool.query(
    "UPDATE public.users SET name='Tên đã chỉnh trong buổi demo' WHERE email=$1",
    [demoAccounts[1].email],
  );
  const second = await seedShowcase(pool);
  assert.equal(second.created, false);
  const preserved = await get("ADMIN", "/api/animals/" + animal.id);
  assert.equal(preserved.animal.notes, "Thao tác người dùng cần giữ");
  assert.equal(
    (await get("ADMIN", "/api/animals?pageSize=100")).total,
    56,
  );
  assert.equal(
    (
      await pool.query("SELECT name FROM public.users WHERE email=$1", [
        demoAccounts[1].email,
      ])
    ).rows[0].name,
    "Tên đã chỉnh trong buổi demo",
  );
  assert.equal(
    (await pool.query("SELECT count(*)::int AS n FROM public.animals")).rows[0]
      .n,
    0,
  );
});
