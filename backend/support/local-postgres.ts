import EmbeddedPostgres from "embedded-postgres";
import { execFile } from "node:child_process";
import { access } from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";
const execute = promisify(execFile);
/** Graceful Windows shutdown also stops PostgreSQL 18 I/O workers. */
export default class LocalPostgres extends EmbeddedPostgres {
  private readonly databaseDirectory: string;
  constructor(
    options: NonNullable<ConstructorParameters<typeof EmbeddedPostgres>[0]>,
  ) {
    super(options);
    if (!options.databaseDir)
      throw new Error("Explicit databaseDir is required.");
    this.databaseDirectory = path.resolve(options.databaseDir);
  }
  override async stop(): Promise<void> {
    if (process.platform !== "win32") {
      await super.stop();
      return;
    }
    try {
      await access(path.join(this.databaseDirectory, "postmaster.pid"));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") return;
      throw error;
    }
    const packageName = "@embedded-postgres/windows-x64";
    const binaries = (await import(packageName)) as { pg_ctl: string };
    if (typeof binaries.pg_ctl !== "string")
      throw new Error("pg_ctl binary unavailable.");
    await execute(
      binaries.pg_ctl,
      ["-D", this.databaseDirectory, "stop", "-m", "fast", "-w", "-t", "15"],
      { windowsHide: true, timeout: 20000 },
    );
  }
}
