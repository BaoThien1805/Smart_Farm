import { mkdir, writeFile } from "node:fs/promises";
import { randomBytes } from "node:crypto";
import pino from "pino";

const log = pino();
const password = randomBytes(24).toString("base64url");
const adminPassword = randomBytes(15).toString("base64url");
await mkdir(".data", { recursive: true });
try {
  await writeFile(
    ".env",
    `NODE_ENV=development\nHOST=127.0.0.1\nPORT=3000\nDATABASE_URL=postgresql://smartfarm:${password}@127.0.0.1:55432/smartfarm\nCORS_ORIGINS=http://localhost:8080,http://127.0.0.1:8080\nSESSION_HOURS=8\nADMIN_EMAIL=admin@smartfarm.local\nADMIN_NAME=Quản trị viên\nADMIN_PASSWORD=${adminPassword}\n`,
    { flag: "wx", mode: 0o600 },
  );
  log.info(
    "Created backend/.env with random local credentials. Read ADMIN_EMAIL and ADMIN_PASSWORD in that file; do not commit it.",
  );
} catch (error) {
  if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
  log.info("Existing .env preserved.");
}
