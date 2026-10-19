import pino from "pino";
import { readConfig } from "../src/config.js";
import { createPool, migrate } from "../src/database.js";
const log = pino();
const pool = createPool(readConfig().DATABASE_URL);
try {
  await migrate(pool);
  log.info("Database migrations applied.");
} finally {
  await pool.end();
}
