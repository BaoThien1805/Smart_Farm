import { access } from "node:fs/promises";
import { spawn } from "node:child_process";
import path from "node:path";
import { readConfig } from "../src/config.js";
import { createPool, migrate } from "../src/database.js";
import { demoPassword, seedShowcase } from "../support/showcase.js";

const config = readConfig();
const url = new URL(config.DATABASE_URL);
if (
  config.NODE_ENV === "production" ||
  !["127.0.0.1", "localhost"].includes(url.hostname)
)
  throw new Error("Showcase is only for a local development database.");
if (process.platform === "win32") {
  const { pg_ctl } = await import("@embedded-postgres/windows-x64");
  const directory = path.resolve(".data/postgres");
  await access(path.join(directory, "PG_VERSION"));
  const execute = (args: string[]) =>
    new Promise<number>((resolve, reject) => {
      const child = spawn(pg_ctl, args, { windowsHide: true, stdio: "ignore" });
      child.on("error", reject);
      child.on("exit", (code) => resolve(code ?? 1));
    });
  if ((await execute(["-D", directory, "status"])) !== 0) {
    if (
      (await execute([
        "-D",
        directory,
        "-l",
        path.resolve(".data/postgres.log"),
        "-o",
        `-p ${Number(url.port || 5432)} -h 127.0.0.1`,
        "start",
        "-w",
        "-t",
        "20",
      ])) !== 0
    )
      throw new Error(
        "Cannot start local PostgreSQL; see backend/.data/postgres.log",
      );
  }
}
const pool = createPool(config.DATABASE_URL);
try {
  await migrate(pool);
  const result = await seedShowcase(pool);
  console.log(
    result.created
      ? "Đã tạo Trang trại Mầm Xanh · DEMO."
      : "Bộ demo đã có; giữ nguyên tài khoản và các thao tác đã làm.",
  );
  console.table(
    result.accounts.map(({ email, role, active }) => ({ email, role, active })),
  );
  console.log("Trại đối chứng:", result.controlEmail);
  console.log("Mật khẩu demo ban đầu:", demoPassword);
} finally {
  await pool.end();
}
