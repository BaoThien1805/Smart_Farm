import { catalogCodesMigration } from "./codes.js";
import { AsyncLocalStorage } from "node:async_hooks";
import { Pool, types, type PoolClient } from "pg";
import { farmMigration } from "./farm/migration.js";
import { inventoryMigration } from "./inventory/migration.js";
import { financeMigration } from "./finance/migration.js";
types.setTypeParser(1082, (value) => value);
const clinicalMigration = `ALTER TABLE health_records ADD COLUMN record_type text NOT NULL DEFAULT 'OBSERVATION' CHECK(record_type IN ('OBSERVATION','EXAM'));
ALTER TABLE health_records ADD COLUMN diagnosis text NOT NULL DEFAULT '' CHECK(length(diagnosis)<=2000);
ALTER TABLE health_records ADD COLUMN treatment text NOT NULL DEFAULT '' CHECK(length(treatment)<=2000);
ALTER TABLE health_records ADD CONSTRAINT health_exam_diagnosis_check CHECK(record_type<>'EXAM' OR length(trim(diagnosis))>0);`;

export function createPool(connectionString: string) {
  return new Pool({
    connectionString,
    max: 10,
    connectionTimeoutMillis: 5000,
    idleTimeoutMillis: 30000,
  });
}

const farmScope = new AsyncLocalStorage<string>();
const scopedPools = new WeakMap<Pool, Pool>();
export function withFarmScope<T>(schema: string, action: () => T): T {
  if (!/^(public|farm_[a-f0-9]{32})$/.test(schema))
    throw new Error("Invalid farm schema");
  return farmScope.run(schema, action);
}
export function createFarmPool(pool: Pool): Pool {
  const scoped = new Proxy(pool, {
    get(target, property) {
      if (property === "query")
        return (text: string, values?: unknown[]) =>
          transaction(scoped, (client) => client.query(text, values));
      return Reflect.get(target, property);
    },
  });
  scopedPools.set(scoped, pool);
  return scoped;
}
export async function createFarmTables(client: PoolClient, schema: string) {
  if (!/^farm_[a-f0-9]{32}$/.test(schema))
    throw new Error("Invalid farm schema");
  await client.query(`CREATE SCHEMA "${schema}"`);
  await client.query("SELECT set_config('search_path', $1, true)", [schema]);
  await client.query(
    farmMigration
      .replaceAll("REFERENCES users(", "REFERENCES public.users(")
      .replace("INSERT INTO schema_migrations(version) VALUES(2);", ""),
  );
  await client.query(
    "ALTER TABLE animals ADD COLUMN name text NOT NULL DEFAULT ''; ALTER TABLE weights ALTER COLUMN kg TYPE numeric(10,3)",
  );
  await client.query(
    inventoryMigration
      .replaceAll("REFERENCES users(", "REFERENCES public.users(")
      .replace("INSERT INTO schema_migrations(version) VALUES(4);", ""),
  );
  await client.query(
    "INSERT INTO species(name) VALUES ('Bò'),('Trâu'),('Heo'),('Dê'),('Cừu'),('Gà'),('Vịt'),('Ngan'),('Ngỗng'),('Cá'),('Tôm'),('Thỏ')",
  );
  await client.query(financeMigration);
  await client.query(clinicalMigration);
  await client.query(catalogCodesMigration);
}

export async function transaction<T>(
  pool: Pool,
  operation: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const root = scopedPools.get(pool);
  const schema = root ? farmScope.getStore() : undefined;
  if (root && !schema) throw new Error("Farm scope is required");
  const client = await (root ?? pool).connect();
  try {
    await client.query("BEGIN");
    if (schema)
      await client.query("SELECT set_config('search_path', $1, true)", [
        schema,
      ]);
    const value = await operation(client);
    await client.query("COMMIT");
    return value;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function migrate(pool: Pool) {
  await transaction(pool, async (client) => {
    await client.query("SELECT pg_advisory_xact_lock(73201001)");
    await client.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      version integer PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now()
    )`);
    const result = await client.query(
      "SELECT version FROM schema_migrations WHERE version = 1",
    );
    if (!result.rowCount) {
      await client.query(`
      CREATE TABLE users (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        email text NOT NULL UNIQUE CHECK (email = lower(email)),
        name text NOT NULL CHECK (length(name) BETWEEN 2 AND 100),
        password_hash text NOT NULL,
        role text NOT NULL CHECK (role IN ('ADMIN', 'STAFF')),
        active boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE TABLE sessions (
        token_hash text PRIMARY KEY,
        user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        expires_at timestamptz NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE INDEX sessions_user_id_idx ON sessions(user_id);
      CREATE INDEX sessions_expiry_idx ON sessions(expires_at);
      INSERT INTO schema_migrations(version) VALUES (1);
    `);
    }
    const farm = await client.query(
      "SELECT version FROM schema_migrations WHERE version=2",
    );
    if (!farm.rowCount) await client.query(farmMigration);
    const profile = await client.query(
      "SELECT version FROM schema_migrations WHERE version=3",
    );
    if (!profile.rowCount)
      await client.query(`
      ALTER TABLE animals ADD COLUMN name text NOT NULL DEFAULT '';
      ALTER TABLE weights ALTER COLUMN kg TYPE numeric(10,3);
      INSERT INTO schema_migrations(version) VALUES(3);
    `);
    const inventory = await client.query(
      "SELECT version FROM schema_migrations WHERE version=4",
    );
    if (!inventory.rowCount) await client.query(inventoryMigration);
    const ownership = await client.query(
      "SELECT version FROM schema_migrations WHERE version=5",
    );
    if (!ownership.rowCount)
      await client.query(`
      CREATE TABLE farms(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL CHECK(length(name) BETWEEN 2 AND 100), schema_name text NOT NULL UNIQUE, created_at timestamptz NOT NULL DEFAULT now());
      INSERT INTO farms(id,name,schema_name) VALUES('00000000-0000-4000-8000-000000000001','Trang trại hiện tại','public');
      ALTER TABLE users ADD COLUMN farm_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES farms(id);
      CREATE INDEX users_farm_idx ON users(farm_id);
      INSERT INTO schema_migrations(version) VALUES(5);
    `);
    const finance = await client.query(
      "SELECT version FROM public.schema_migrations WHERE version=6",
    );
    if (!finance.rowCount) {
      const farms = await client.query<{ schema_name: string }>(
        "SELECT schema_name FROM public.farms ORDER BY id",
      );
      for (const farm of farms.rows) {
        if (!/^(public|farm_[a-f0-9]{32})$/.test(farm.schema_name))
          throw new Error("Invalid farm schema");
        await client.query("SELECT set_config('search_path', $1, true)", [
          farm.schema_name,
        ]);
        const exists = await client.query(
          "SELECT to_regclass($1) AS table_name",
          [farm.schema_name + ".finance_entries"],
        );
        if (!exists.rows[0].table_name) await client.query(financeMigration);
      }
      await client.query("SELECT set_config('search_path', 'public', true)");
      await client.query(
        "INSERT INTO public.schema_migrations(version) VALUES(6)",
      );
    }
    const location = await client.query(
      "SELECT version FROM public.schema_migrations WHERE version=7",
    );
    if (!location.rowCount)
      await client.query(`
      ALTER TABLE public.farms ADD COLUMN latitude double precision;
      ALTER TABLE public.farms ADD COLUMN longitude double precision;
      ALTER TABLE public.farms ADD CONSTRAINT farms_location_check CHECK (
        (latitude IS NULL AND longitude IS NULL) OR
        (latitude IS NOT NULL AND longitude IS NOT NULL AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)
      );
      INSERT INTO public.schema_migrations(version) VALUES(7);
    `);
    const roles = await client.query(
      "SELECT version FROM public.schema_migrations WHERE version=8",
    );
    if (!roles.rowCount) {
      await client.query(
        "ALTER TABLE public.users DROP CONSTRAINT users_role_check; ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK(role IN ('ADMIN','STAFF','VET','ACCOUNTANT'))",
      );
      const farms = await client.query<{ schema_name: string }>(
        "SELECT schema_name FROM public.farms ORDER BY id",
      );
      for (const farm of farms.rows) {
        if (!/^(public|farm_[a-f0-9]{32})$/.test(farm.schema_name))
          throw new Error("Invalid farm schema");
        await client.query("SELECT set_config('search_path', $1, true)", [
          farm.schema_name,
        ]);
        await client.query(clinicalMigration);
      }
      await client.query("SELECT set_config('search_path', 'public', true)");
      await client.query(
        "INSERT INTO public.schema_migrations(version) VALUES(8)",
      );
    }
    const profiles = await client.query(
      "SELECT 1 FROM public.schema_migrations WHERE version=9",
    );
    if (!profiles.rowCount) {
      await client.query(
        "ALTER TABLE public.users ADD COLUMN avatar_data text CHECK(avatar_data IS NULL OR (avatar_data LIKE 'data:image/jpeg;base64,%' AND length(avatar_data)<=1398104))",
      );
      const farms = await client.query<{ id: string; schema_name: string }>(
        "SELECT id,schema_name FROM public.farms ORDER BY id",
      );
      for (const farm of farms.rows) {
        if (!/^(public|farm_[a-f0-9]{32})$/.test(farm.schema_name))
          throw new Error("Invalid farm schema");
        await client.query("SELECT set_config('search_path',$1,true)", [
          farm.schema_name,
        ]);
        // The previous empty selection meant all species. Preserve that intent.
        await client.query(
          `INSERT INTO user_species(user_id,species_id)
          SELECT u.id,s.id FROM public.users u JOIN user_species_preferences p ON p.user_id=u.id CROSS JOIN species s
          WHERE u.farm_id=$1 AND u.role='ADMIN' AND p.configured AND NOT EXISTS(SELECT 1 FROM user_species x WHERE x.user_id=u.id)
          ON CONFLICT DO NOTHING`,
          [farm.id],
        );
        // Preserve visibility of existing animal dossiers during the upgrade.
        await client.query(
          `INSERT INTO user_species(user_id,species_id)
          SELECT u.id,b.species_id FROM public.users u JOIN user_species_preferences p ON p.user_id=u.id
          CROSS JOIN animals a JOIN breeds b ON b.id=a.breed_id
          WHERE u.farm_id=$1 AND u.role='ADMIN' AND p.configured ON CONFLICT DO NOTHING`,
          [farm.id],
        );
      }
      await client.query("SELECT set_config('search_path','public',true)");
      await client.query(
        "INSERT INTO public.schema_migrations(version) VALUES(9)",
      );
    }
    const codes = await client.query(
      "SELECT 1 FROM public.schema_migrations WHERE version=10",
    );
    if (!codes.rowCount) {
      await client.query(
        "ALTER TABLE public.users ADD COLUMN code text CHECK(code IS NULL OR length(trim(code)) BETWEEN 1 AND 100); CREATE UNIQUE INDEX users_farm_code_unique ON public.users(farm_id,upper(code))",
      );
      const farms = await client.query<{ schema_name: string }>(
        "SELECT schema_name FROM public.farms",
      );
      for (const farm of farms.rows) {
        if (!/^(public|farm_[a-f0-9]{32})$/.test(farm.schema_name))
          throw new Error("Invalid farm schema");
        await client.query("SELECT set_config('search_path',$1,true)", [
          farm.schema_name,
        ]);
        await client.query(catalogCodesMigration);
      }
      await client.query("SELECT set_config('search_path','public',true)");
      await client.query(
        "INSERT INTO public.schema_migrations(version) VALUES(10)",
      );
    }
    const deletedAccounts = await client.query(
      "SELECT 1 FROM public.schema_migrations WHERE version=11",
    );
    if (!deletedAccounts.rowCount) {
      await client.query(
        "ALTER TABLE public.users ADD COLUMN deleted_at timestamptz; ALTER TABLE public.users ADD CONSTRAINT users_deleted_inactive_check CHECK(deleted_at IS NULL OR NOT active); CREATE INDEX users_visible_farm_idx ON public.users(farm_id) WHERE deleted_at IS NULL",
      );
      await client.query(
        "INSERT INTO public.schema_migrations(version) VALUES(11)",
      );
    }
  });
}
