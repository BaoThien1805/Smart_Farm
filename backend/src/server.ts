import { buildApp } from "./app.js";
import { readConfig } from "./config.js";
import { createPool } from "./database.js";

const config = readConfig();
const pool = createPool(config.DATABASE_URL);
const app = await buildApp(pool, config);
pool.on("error", (error) =>
  app.log.error({ type: error.name }, "Database connection failed"),
);
let closing = false;
async function shutdown() {
  if (closing) return;
  closing = true;
  await app.close();
  await pool.end();
}
process.on("SIGINT", () => {
  void shutdown();
});
process.on("SIGTERM", () => {
  void shutdown();
});
try {
  const migration = await pool.query(
    "SELECT 1 FROM schema_migrations WHERE version=11",
  );
  if (!migration.rowCount)
    throw new Error("Run db:migrate before starting the API.");
  await app.listen({ host: config.HOST, port: config.PORT });
} catch (error) {
  app.log.error(
    { type: error instanceof Error ? error.name : "Unknown" },
    "Startup failed; check database and migrations",
  );
  await shutdown();
  process.exitCode = 1;
}
