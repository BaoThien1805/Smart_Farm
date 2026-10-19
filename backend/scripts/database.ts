import EmbeddedPostgres from "../support/local-postgres.js";
import { access } from "node:fs/promises";
import pino from "pino";
import { readConfig } from "../src/config.js";

const log = pino();
const config = readConfig();
if (config.NODE_ENV === "production")
  throw new Error("Embedded database is only for local development.");
const url = new URL(config.DATABASE_URL);
if (!["127.0.0.1", "localhost"].includes(url.hostname))
  throw new Error("Local database must use loopback.");
const database = url.pathname.slice(1);
if (!/^[a-z][a-z0-9_]*$/.test(database))
  throw new Error("Invalid local database name.");
const pg = new EmbeddedPostgres({
  databaseDir: ".data/postgres",
  user: decodeURIComponent(url.username),
  password: decodeURIComponent(url.password),
  port: Number(url.port || 5432),
  persistent: true,
  authMethod: "scram-sha-256",
  postgresFlags: ["-h", "127.0.0.1"],
  initdbFlags: ["--encoding=UTF8", "--locale=C"],
  onLog: () => log.debug("PostgreSQL output"),
  onError: () => log.warn("PostgreSQL diagnostic output"),
});
let initialized = true;
try {
  await access(".data/postgres/PG_VERSION");
} catch (error) {
  if ((error as NodeJS.ErrnoException).code === "ENOENT") initialized = false;
  else throw error;
}
if (!initialized) await pg.initialise();
await pg.start();
let stopped = false;
async function stop() {
  if (stopped) return;
  stopped = true;
  clearInterval(keepAlive);
  await pg.stop();
  log.info("Local PostgreSQL stopped; data preserved.");
}
const keepAlive = setInterval(() => {}, 60000);
process.on("SIGINT", () => {
  void stop();
});
process.on("SIGTERM", () => {
  void stop();
});
const client = pg.getPgClient();
try {
  await client.connect();
  const result = await client.query(
    "SELECT 1 FROM pg_database WHERE datname=$1",
    [database],
  );
  if (!result.rowCount) await pg.createDatabase(database);
  log.info(
    { port: Number(url.port), database },
    "Local PostgreSQL ready. Keep this terminal open.",
  );
} catch (error) {
  await stop();
  throw error;
} finally {
  await client.end();
}
