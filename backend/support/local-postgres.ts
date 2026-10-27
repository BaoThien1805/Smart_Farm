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
  override async start(): Promise<void> {
    if (process.platform !== "win32") return super.start();
    // pg_ctl starts PostgreSQL with the restricted token required on Windows,
    // including when the parent editor happens to run as Administrator.
    const { pg_ctl } = await import("@embedded-postgres/windows-x64");
    await execute(
      pg_ctl,
      [
        "-D",
        this.databaseDirectory,
        "-l",
        path.join(this.databaseDirectory, "server.log"),
        "-o",
        `-p ${this.options.port} -h 127.0.0.1`,
        "start",
        "-w",
        "-t",
        "20",
      ],
      { windowsHide: true, timeout: 25000 },
    );
  }
  override async createDatabase(name: string): Promise<void> {
    if (process.platform !== "win32") return super.createDatabase(name);
    const client = this.getPgClient(undefined, "127.0.0.1");
    try {
      await client.connect();
      await client.query(`CREATE DATABASE ${client.escapeIdentifier(name)}`);
    } finally {
      await client.end();
    }
  }
  override async dropDatabase(name: string): Promise<void> {
    if (process.platform !== "win32") return super.dropDatabase(name);
    const client = this.getPgClient(undefined, "127.0.0.1");
    try {
      await client.connect();
      await client.query(`DROP DATABASE ${client.escapeIdentifier(name)}`);
    } finally {
      await client.end();
    }
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
