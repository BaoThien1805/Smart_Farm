import pino from "pino";
import { z } from "zod";
import { readConfig } from "../src/config.js";
import { createPool, transaction } from "../src/database.js";
import { emailSchema, passwordSchema } from "../src/auth/service.js";
import { hashPassword } from "../src/security.js";

const log = pino();
const email = emailSchema.parse(process.env.ADMIN_EMAIL);
const password = passwordSchema.parse(process.env.ADMIN_PASSWORD);
const name = z.string().trim().min(2).max(100).parse(process.env.ADMIN_NAME);
const pool = createPool(readConfig().DATABASE_URL);
try {
  const passwordHash = await hashPassword(password);
  await transaction(pool, async (client) => {
    await client.query("SELECT pg_advisory_xact_lock(73201002)");
    const existing = await client.query("SELECT id FROM users WHERE role=$1", [
      "ADMIN",
    ]);
    if (existing.rowCount) {
      log.info("Administrator already exists; password preserved.");
      return;
    }
    await client.query(
      "INSERT INTO users(email,name,password_hash,role) VALUES($1,$2,$3,'ADMIN')",
      [email, name, passwordHash],
    );
    log.info("Administrator created. Credentials come from backend/.env.");
  });
} finally {
  await pool.end();
}
