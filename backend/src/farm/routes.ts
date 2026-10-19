import { codeKind, codeSchema, suggestCode } from "../codes.js";
import { financeTotals, monthlyFinance } from "../finance/summary.js";
import { normalizeAnimalImage } from "./images.js";
import { createHash } from "node:crypto";
import type { FastifyInstance, FastifyRequest } from "fastify";
import type { Pool, PoolClient } from "pg";
import { z } from "zod";
import { transaction } from "../database.js";
import { ApiError } from "../auth/service.js";
import { farmSpecies } from "./species-scope.js";

const uuid = z.string().uuid();
const speciesFilter = z
  .string()
  .transform((v) => v.split(","))
  .pipe(z.array(uuid).min(1).max(100))
  .optional();
const name = z.string().trim().min(1).max(100);
const notes = z.string().trim().max(2000).default("");
export const date = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine(
    (v) =>
      v >= "1900-01-01" &&
      v <= "2100-12-31" &&
      !Number.isNaN(Date.parse(v)) &&
      new Date(v).toISOString().slice(0, 10) === v,
    "Ngày không hợp lệ.",
  );
export const today = () =>
  new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
const animalBody = z
  .object({
    photoBase64: z.string().min(1).max(1398104).nullable().optional(),
    code: name,
    name: z.string().trim().max(100).default(""),
    breedId: uuid,
    gender: z.enum(["MALE", "FEMALE", "UNKNOWN"]),
    birthDate: date.nullable().default(null),
    arrivalDate: date,
    origin: notes,
    notes,
    penId: uuid,
  })
  .strict();
const health = z.enum(["NORMAL", "NEEDS_CARE"]);
const eventBody = z.object({ requestId: uuid, date, notes }).strict();
const careBody = z
  .object({
    animalId: uuid,
    kind: z.enum(["VACCINATION", "CHECKUP"]),
    title: name,
    dueDate: date,
    notes,
  })
  .strict();
const animalSelect = `SELECT a.id,a.code,a.name,a.image_data AS "imageData",a.breed_id AS "breedId",b.name AS "breedName",b.species_id AS "speciesId",s.name AS "speciesName",a.gender,a.birth_date AS "birthDate",a.arrival_date AS "arrivalDate",a.origin,a.notes,a.pen_id AS "penId",p.name AS "penName",a.status,a.health_status AS "healthStatus",a.ended_date AS "endedDate" FROM animals a JOIN breeds b ON b.id=a.breed_id JOIN species s ON s.id=b.species_id JOIN pens p ON p.id=a.pen_id`;
const careSelect = `SELECT t.id,t.animal_id AS "animalId",a.code AS "animalCode",t.kind,t.title,t.due_date AS "dueDate",t.notes,t.status,t.actual_date AS "actualDate",u.name AS "actorName" FROM care_tasks t JOIN animals a ON a.id=t.animal_id JOIN public.users u ON u.id=t.actor_id`;
function fail(message: string, code = "CONFLICT"): never {
  throw new ApiError(409, code, message);
}
export async function animal(c: PoolClient, id: string, active = true) {
  const r = await c.query("SELECT * FROM animals WHERE id=$1 FOR UPDATE", [id]);
  if (!r.rows[0])
    throw new ApiError(404, "NOT_FOUND", "Không tìm thấy vật nuôi.");
  if (active && r.rows[0].status !== "ACTIVE")
    fail("Vật nuôi đã kết thúc nuôi.");
  return r.rows[0];
}
export function actualDate(value: string, arrival: string) {
  if (value > today() || value < arrival)
    fail("Ngày phải từ ngày nhập đàn đến hôm nay.", "INVALID_DATE");
}
export async function capacity(c: PoolClient, penId: string, exclude?: string) {
  const r = await c.query("SELECT * FROM pens WHERE id=$1 FOR UPDATE", [penId]);
  if (!r.rows[0] || !r.rows[0].active)
    fail("Chuồng không tồn tại hoặc đã ngừng sử dụng.");
  const count = await c.query(
    "SELECT count(*)::int AS n FROM animals WHERE pen_id=$1 AND status='ACTIVE' AND ($2::uuid IS NULL OR id<>$2)",
    [penId, exclude ?? null],
  );
  if (count.rows[0].n >= r.rows[0].capacity)
    fail("Chuồng đã đủ sức chứa.", "PEN_FULL");
}
export async function registerFarmRoutes(
  app: FastifyInstance,
  pool: Pool,
  hooks: {
    authenticate: (r: FastifyRequest) => Promise<void>;
    admin: (r: FastifyRequest) => Promise<void>;
    operate: (r: FastifyRequest) => Promise<void>;
    care: (r: FastifyRequest) => Promise<void>;
    examine: (r: FastifyRequest) => Promise<void>;
  },
) {
  const read = { preHandler: hooks.authenticate };
  const operate = { preHandler: hooks.operate };
  const care = { preHandler: hooks.care };
  const examine = { preHandler: hooks.examine };
  const admin = { preHandler: hooks.admin };
  const idOf = (r: FastifyRequest) => z.object({ id: uuid }).parse(r.params).id;
  async function write<T>(
    r: FastifyRequest,
    body: unknown,
    action: (c: PoolClient) => Promise<T>,
    requestId?: string,
  ): Promise<T> {
    return transaction(pool, async (c) => {
      await c.query("SELECT pg_advisory_xact_lock(73201003)");
      const digest = createHash("sha256")
        .update(JSON.stringify([r.method, r.url, body]))
        .digest("hex");
      if (requestId) {
        const prev = await c.query(
          "SELECT digest,result FROM farm_operations WHERE actor_id=$1 AND request_id=$2",
          [r.account!.id, requestId],
        );
        if (prev.rows[0]) {
          if (prev.rows[0].digest !== digest)
            fail("Mã yêu cầu đã được dùng cho thao tác khác.");
          return prev.rows[0].result as T;
        }
      }
      const result = await action(c);
      if (requestId)
        await c.query(
          "INSERT INTO farm_operations(actor_id,request_id,digest,result) VALUES($1,$2,$3,$4)",
          [r.account!.id, requestId, digest, JSON.stringify(result)],
        );
      return result;
    });
  }
  app.get("/api/code-suggestion", read, async (r) => {
    const q = z
      .object({ kind: codeKind, name: z.string().trim().max(100).default("") })
      .strict()
      .parse(r.query);
    if (q.kind === "users" && r.account!.role !== "ADMIN")
      throw new ApiError(
        403,
        "FORBIDDEN",
        "Bạn không có quyền quản lý nhân sự.",
      );
    return { code: await suggestCode(pool, q.kind, q.name, r.account!.farmId) };
  });
  app.get("/api/farm/species-settings", read, async (r) => {
    const { configured, speciesIds } = await farmSpecies(
      pool,
      r.account!.farmId,
    );
    return { configured, speciesIds };
  });
  app.get("/api/farm/catalogs", read, async (r) => {
    const q = z
      .object({ includeAvailable: z.enum(["true"]).optional() })
      .parse(r.query);
    if (q.includeAvailable && r.account!.role !== "ADMIN")
      throw new ApiError(
        403,
        "FORBIDDEN",
        "Bạn không có quyền xem danh mục khởi tạo.",
      );
    const settings = await farmSpecies(pool, r.account!.farmId);
    const restricted = settings.configured && !q.includeAvailable;
    const [species, breeds, areas, pens] = await Promise.all([
      pool.query(
        "SELECT id,name,code FROM species WHERE NOT $1::boolean OR id=ANY($2::uuid[]) ORDER BY name",
        [restricted, settings.speciesIds],
      ),
      pool.query(
        'SELECT id,name,code,species_id AS "speciesId" FROM breeds WHERE NOT $1::boolean OR species_id=ANY($2::uuid[]) ORDER BY name',
        [restricted, settings.speciesIds],
      ),
      pool.query("SELECT id,name,code FROM areas ORDER BY name"),
      pool.query(
        `SELECT p.id,p.code,p.name,p.area_id AS "areaId",p.capacity,p.active,count(a.id)::int AS occupied FROM pens p LEFT JOIN animals a ON a.pen_id=p.id AND a.status='ACTIVE' GROUP BY p.id ORDER BY p.code`,
      ),
    ]);
    return {
      species: species.rows,
      breeds: breeds.rows,
      areas: areas.rows,
      pens: pens.rows,
    };
  });
  for (const kind of ["species", "breeds", "areas", "pens"] as const) {
    const schema =
      kind === "breeds"
        ? z
            .object({ name, code: codeSchema.optional(), speciesId: uuid })
            .strict()
        : kind === "pens"
          ? z
              .object({
                code: name,
                name,
                areaId: uuid,
                capacity: z.number().int().min(1).max(100000),
                active: z.boolean().default(true),
              })
              .strict()
          : z.object({ name, code: codeSchema.optional() }).strict();
    for (const method of ["POST", "PATCH"] as const)
      app.route({
        method,
        url: `/api/farm/${kind}${method === "PATCH" ? "/:id" : ""}`,
        ...admin,
        handler: async (r) => {
          const b = schema.parse(r.body) as Record<string, unknown>;
          return write(r, b, async (c) => {
            const selection =
              kind === "species" && method === "POST"
                ? await farmSpecies(c, r.account!.farmId)
                : null;
            if (selection?.configured) {
              const found = await c.query(
                "SELECT id,code FROM species WHERE lower(name)=lower($1) ORDER BY id LIMIT 1",
                [b.name],
              );
              const existing = found.rows[0]?.id as string | undefined;
              if (existing && !selection.speciesIds.includes(existing)) {
                if (b.code !== undefined || found.rows[0].code == null) {
                  const code =
                    b.code ??
                    (await suggestCode(
                      c,
                      "species",
                      String(b.name),
                      r.account!.farmId,
                    ));
                  await c.query("UPDATE species SET code=$1 WHERE id=$2", [
                    code,
                    existing,
                  ]);
                }
                await c.query(
                  "INSERT INTO user_species(user_id,species_id) VALUES($1,$2) ON CONFLICT DO NOTHING",
                  [selection.ownerId, existing],
                );
                return { item: { id: existing } };
              }
            }
            if (method === "PATCH") {
              const id = idOf(r);
              const current = await c.query(
                `SELECT * FROM ${kind} WHERE id=$1 FOR UPDATE`,
                [id],
              );
              if (!current.rowCount)
                throw new ApiError(
                  404,
                  "NOT_FOUND",
                  "Không tìm thấy danh mục.",
                );
              if (
                kind === "breeds" &&
                b.speciesId !== current.rows[0].species_id
              ) {
                const used = await c.query(
                  "SELECT 1 FROM animals WHERE breed_id=$1 LIMIT 1",
                  [id],
                );
                if (used.rowCount)
                  fail("Giống đã có vật nuôi, không thể đổi loài.");
              }
              if (kind === "pens") {
                const n = await c.query(
                  "SELECT count(*)::int AS n FROM animals WHERE pen_id=$1 AND status='ACTIVE'",
                  [id],
                );
                if (
                  n.rows[0].n > Number(b.capacity) ||
                  (!b.active && n.rows[0].n > 0)
                )
                  fail(
                    "Sức chứa/trạng thái không phù hợp số vật nuôi đang ở chuồng.",
                  );
              }
            }
            const columns =
              kind === "breeds"
                ? ["name", "species_id"]
                : kind === "pens"
                  ? ["code", "name", "area_id", "capacity", "active"]
                  : ["name"];
            const values =
              kind === "breeds"
                ? [b.name, b.speciesId]
                : kind === "pens"
                  ? [b.code, b.name, b.areaId, b.capacity, b.active]
                  : [b.name];
            if (
              kind !== "pens" &&
              (method === "POST" || b.code !== undefined)
            ) {
              columns.push("code");
              values.push(
                b.code ??
                  (await suggestCode(
                    c,
                    kind,
                    String(b.name),
                    r.account!.farmId,
                  )),
              );
            }
            const sql =
              method === "POST"
                ? `INSERT INTO ${kind}(${columns.join(",")}) VALUES(${values.map((_, i) => `$${i + 1}`).join(",")}) RETURNING id`
                : `UPDATE ${kind} SET ${columns.map((v, i) => `${v}=$${i + 1}`).join(",")} WHERE id=$${values.length + 1} RETURNING id`;
            if (method === "PATCH") values.push(idOf(r));
            const item = (await c.query(sql, values)).rows[0];
            if (selection?.configured)
              await c.query(
                "INSERT INTO user_species(user_id,species_id) VALUES($1,$2) ON CONFLICT DO NOTHING",
                [selection.ownerId, item.id],
              );
            return { item };
          });
        },
      });
    app.delete(`/api/farm/${kind}/:id`, admin, async (r) =>
      write(r, null, async (c) => {
        const result = await c.query(
          `DELETE FROM ${kind} WHERE id=$1 RETURNING id`,
          [idOf(r)],
        );
        if (!result.rowCount)
          throw new ApiError(404, "NOT_FOUND", "Không tìm thấy danh mục.");
        return { ok: true };
      }),
    );
  }
  app.get("/api/animals", read, async (r) => {
    const q = z
      .object({
        page: z.coerce.number().int().min(1).max(100000).default(1),
        pageSize: z.coerce.number().int().min(1).max(100).default(20),
        search: z.string().max(100).default(""),
        status: z.enum(["ACTIVE", "DEAD", "SOLD"]).optional(),
        speciesId: uuid.optional(),
        speciesIds: speciesFilter,
        penId: uuid.optional(),
        healthStatus: health.optional(),
      })
      .parse(r.query);
    const values = [
      `%${q.search.replace(/[\\%_]/g, "\\$&")}%`,
      q.status ?? null,
      q.speciesId ?? null,
      q.penId ?? null,
      q.healthStatus ?? null,
      q.speciesIds ?? null,
    ];
    const where = ` WHERE (a.code ILIKE $1 OR a.name ILIKE $1) AND ($2::text IS NULL OR a.status=$2) AND ($3::uuid IS NULL OR b.species_id=$3) AND ($4::uuid IS NULL OR a.pen_id=$4) AND ($5::text IS NULL OR a.health_status=$5) AND ($6::uuid[] IS NULL OR b.species_id=ANY($6))`;
    const total = await pool.query(
      `SELECT count(*)::int AS total FROM animals a JOIN breeds b ON b.id=a.breed_id${where}`,
      values,
    );
    const rows = await pool.query(
      `${animalSelect}${where} ORDER BY a.code,a.id LIMIT $7 OFFSET $8`,
      [...values, q.pageSize, (q.page - 1) * q.pageSize],
    );
    return {
      animals: rows.rows,
      total: total.rows[0].total,
      page: q.page,
      pageSize: q.pageSize,
    };
  });
  app.post("/api/animals", { ...operate, bodyLimit: 1500000 }, async (r) => {
    const b = animalBody.parse(r.body);
    const image = b.photoBase64
      ? await normalizeAnimalImage(b.photoBase64)
      : null;
    actualDate(b.arrivalDate, b.birthDate ?? b.arrivalDate);
    if (b.birthDate && b.birthDate > b.arrivalDate)
      fail("Ngày sinh phải trước hoặc bằng ngày nhập đàn.");
    return write(r, b, async (c) => {
      await capacity(c, b.penId);
      const result = await c.query(
        "INSERT INTO animals(code,breed_id,gender,birth_date,arrival_date,origin,notes,pen_id,name,image_data) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id",
        [
          b.code,
          b.breedId,
          b.gender,
          b.birthDate,
          b.arrivalDate,
          b.origin,
          b.notes,
          b.penId,
          b.name,
          image,
        ],
      );
      return { animal: result.rows[0] };
    });
  });
  app.patch(
    "/api/animals/:id",
    { ...operate, bodyLimit: 1500000 },
    async (r) => {
      const b = animalBody.omit({ penId: true }).parse(r.body);
      const image = b.photoBase64
        ? await normalizeAnimalImage(b.photoBase64)
        : null;
      const id = idOf(r);
      return write(r, b, async (c) => {
        const a = await animal(c, id);
        actualDate(b.arrivalDate, b.birthDate ?? b.arrivalDate);
        if (a.arrival_date !== b.arrivalDate)
          fail("Không đổi ngày nhập đàn sau khi tạo hồ sơ.");
        const oldBreed = await c.query(
          "SELECT species_id FROM breeds WHERE id=$1",
          [a.breed_id],
        );
        const newBreed = await c.query(
          "SELECT species_id FROM breeds WHERE id=$1",
          [b.breedId],
        );
        if (
          !newBreed.rows[0] ||
          newBreed.rows[0].species_id !== oldBreed.rows[0].species_id
        )
          fail("Giống phải thuộc loài ban đầu.");
        await c.query(
          "UPDATE animals SET code=$2,breed_id=$3,gender=$4,birth_date=$5,origin=$6,notes=$7,name=$8,image_data=CASE WHEN $9::boolean THEN $10::text ELSE image_data END WHERE id=$1",
          [
            id,
            b.code,
            b.breedId,
            b.gender,
            b.birthDate,
            b.origin,
            b.notes,
            b.name,
            b.photoBase64 !== undefined,
            image,
          ],
        );
        return { ok: true };
      });
    },
  );
  app.get("/api/animals/:id", read, async (r) => {
    const id = idOf(r);
    const a = await pool.query(`${animalSelect} WHERE a.id=$1`, [id]);
    if (!a.rowCount)
      throw new ApiError(404, "NOT_FOUND", "Không tìm thấy vật nuôi.");
    const [weights, transfers, healthRecords, careTasks] = await Promise.all([
      pool.query(
        'SELECT w.id,w.date,w.kg::float8 AS kg,w.notes,u.name AS "actorName" FROM weights w JOIN public.users u ON u.id=w.actor_id WHERE animal_id=$1 ORDER BY w.date,w.id',
        [id],
      ),
      pool.query(
        'SELECT t.id,t.date,t.notes,p.name AS "fromPenName",p2.name AS "toPenName",u.name AS "actorName" FROM transfers t JOIN pens p ON p.id=t.from_pen_id JOIN pens p2 ON p2.id=t.to_pen_id JOIN public.users u ON u.id=t.actor_id WHERE animal_id=$1 ORDER BY date DESC,t.id',
        [id],
      ),
      pool.query(
        'SELECT h.id,h.date,h.content,h.status,h.notes,h.record_type AS "recordType",h.diagnosis,h.treatment,u.name AS "actorName" FROM health_records h JOIN public.users u ON u.id=h.actor_id WHERE animal_id=$1 ORDER BY h.date DESC,h.created_at DESC,h.id DESC',
        [id],
      ),
      pool.query(
        `${careSelect} WHERE t.animal_id=$1 ORDER BY t.due_date DESC,t.id`,
        [id],
      ),
    ]);
    return {
      animal: a.rows[0],
      weights: weights.rows,
      transfers: transfers.rows,
      healthRecords: healthRecords.rows,
      careTasks: careTasks.rows,
    };
  });
  app.delete("/api/animals/:id", admin, async (r) =>
    write(r, null, async (c) => {
      const id = idOf(r);
      await animal(c, id);
      const result = await c.query(
        "DELETE FROM animals WHERE id=$1 RETURNING id",
        [id],
      );
      return { ok: !!result.rowCount };
    }),
  );
  app.post("/api/animals/:id/transfer", operate, async (r) => {
    const b = eventBody.extend({ penId: uuid }).parse(r.body);
    const id = idOf(r);
    return write(
      r,
      b,
      async (c) => {
        const a = await animal(c, id);
        actualDate(b.date, a.arrival_date);
        if (a.pen_id === b.penId) fail("Vật nuôi đã ở chuồng này.");
        const last = await c.query(
          "SELECT max(date)::text AS date FROM transfers WHERE animal_id=$1",
          [id],
        );
        if (last.rows[0].date && b.date < last.rows[0].date)
          fail("Ngày chuyển phải sau hoặc bằng lần chuyển trước.");
        await capacity(c, b.penId);
        await c.query(
          "INSERT INTO transfers(animal_id,from_pen_id,to_pen_id,date,notes,actor_id) VALUES($1,$2,$3,$4,$5,$6)",
          [id, a.pen_id, b.penId, b.date, b.notes, r.account!.id],
        );
        await c.query("UPDATE animals SET pen_id=$2 WHERE id=$1", [
          id,
          b.penId,
        ]);
        return { ok: true };
      },
      b.requestId,
    );
  });
  app.post("/api/animals/:id/weights", operate, async (r) => {
    const b = eventBody
      .extend({
        kg: z
          .number()
          .positive()
          .max(100000)
          .refine(
            (v) => Math.abs(v * 1000 - Math.round(v * 1000)) < 1e-7,
            "Tối đa ba chữ số thập phân.",
          ),
      })
      .parse(r.body);
    const id = idOf(r);
    return write(
      r,
      b,
      async (c) => {
        const a = await animal(c, id);
        actualDate(b.date, a.arrival_date);
        await c.query(
          "INSERT INTO weights(animal_id,date,kg,notes,actor_id) VALUES($1,$2,$3,$4,$5)",
          [id, b.date, b.kg, b.notes, r.account!.id],
        );
        return { ok: true };
      },
      b.requestId,
    );
  });
  async function updateHealth(c: PoolClient, id: string) {
    await c.query(
      `UPDATE animals SET health_status=(SELECT status FROM health_records WHERE animal_id=$1 ORDER BY date DESC,created_at DESC,id DESC LIMIT 1) WHERE id=$1`,
      [id],
    );
  }
  app.post("/api/animals/:id/health", care, async (r) => {
    const b = eventBody.extend({ content: name, status: health }).parse(r.body);
    const id = idOf(r);
    return write(
      r,
      b,
      async (c) => {
        const a = await animal(c, id);
        actualDate(b.date, a.arrival_date);
        await c.query(
          "INSERT INTO health_records(animal_id,date,content,status,notes,actor_id) VALUES($1,$2,$3,$4,$5,$6)",
          [id, b.date, b.content, b.status, b.notes, r.account!.id],
        );
        await updateHealth(c, id);
        return { ok: true };
      },
      b.requestId,
    );
  });
  app.post("/api/animals/:id/exams", examine, async (r) => {
    const b = eventBody
      .extend({
        content: name,
        status: health,
        diagnosis: z.string().trim().min(1).max(2000),
        treatment: z.string().trim().max(2000).default(""),
      })
      .parse(r.body);
    const id = idOf(r);
    return write(
      r,
      b,
      async (c) => {
        const a = await animal(c, id);
        actualDate(b.date, a.arrival_date);
        await c.query(
          "INSERT INTO health_records(animal_id,date,content,status,notes,actor_id,record_type,diagnosis,treatment) VALUES($1,$2,$3,$4,$5,$6,'EXAM',$7,$8)",
          [
            id,
            b.date,
            b.content,
            b.status,
            b.notes,
            r.account!.id,
            b.diagnosis,
            b.treatment,
          ],
        );
        await updateHealth(c, id);
        return { ok: true };
      },
      b.requestId,
    );
  });
  app.post("/api/animals/:id/death", admin, async (r) => {
    const b = eventBody.parse(r.body);
    const id = idOf(r);
    return write(
      r,
      b,
      async (c) => {
        const a = await animal(c, id);
        actualDate(b.date, a.arrival_date);
        const latest = await c.query(
          `SELECT max(date)::text AS date FROM (SELECT date FROM weights WHERE animal_id=$1 UNION ALL SELECT date FROM transfers WHERE animal_id=$1 UNION ALL SELECT date FROM health_records WHERE animal_id=$1) events`,
          [id],
        );
        if (latest.rows[0].date && b.date < latest.rows[0].date)
          fail("Ngày chết không thể trước lịch sử đã ghi.");
        await c.query(
          "UPDATE animals SET status='DEAD',ended_date=$2,notes=concat_ws(E'\\n',notes,$3::text) WHERE id=$1",
          [id, b.date, b.notes],
        );
        await c.query(
          "UPDATE care_tasks SET status='CANCELLED' WHERE animal_id=$1 AND status='PENDING'",
          [id],
        );
        return { ok: true };
      },
      b.requestId,
    );
  });
  app.get("/api/care-tasks", read, async (r) => {
    const q = z
      .object({
        status: z.enum(["PENDING", "DONE", "CANCELLED"]).optional(),
        animalId: uuid.optional(),
        speciesIds: speciesFilter,
        page: z.coerce.number().int().min(1).max(100000).default(1),
        pageSize: z.coerce.number().int().min(1).max(100).default(20),
      })
      .parse(r.query);
    const where =
      " WHERE ($1::text IS NULL OR t.status=$1) AND ($2::uuid IS NULL OR t.animal_id=$2) AND ($3::uuid[] IS NULL OR t.animal_id IN (SELECT ax.id FROM animals ax JOIN breeds bx ON bx.id=ax.breed_id WHERE bx.species_id=ANY($3)))";
    const args = [q.status ?? null, q.animalId ?? null, q.speciesIds ?? null];
    const result = await pool.query(
      `${careSelect}${where} ORDER BY t.due_date,t.id LIMIT $4 OFFSET $5`,
      [...args, q.pageSize, (q.page - 1) * q.pageSize],
    );
    const total = await pool.query(
      `SELECT count(*)::int AS n FROM care_tasks t${where}`,
      args,
    );
    return {
      tasks: result.rows,
      total: total.rows[0].n,
      page: q.page,
      pageSize: q.pageSize,
      today: today(),
    };
  });
  app.post("/api/care-tasks", care, async (r) => {
    const b = careBody.parse(r.body);
    return write(r, b, async (c) => {
      const a = await animal(c, b.animalId);
      if (b.dueDate < a.arrival_date) fail("Ngày hẹn phải từ ngày nhập đàn.");
      const task = await c.query(
        "INSERT INTO care_tasks(animal_id,kind,title,due_date,notes,actor_id) VALUES($1,$2,$3,$4,$5,$6) RETURNING id",
        [b.animalId, b.kind, b.title, b.dueDate, b.notes, r.account!.id],
      );
      return { task: task.rows[0] };
    });
  });
  async function pending(c: PoolClient, id: string) {
    const result = await c.query(
      "SELECT * FROM care_tasks WHERE id=$1 FOR UPDATE",
      [id],
    );
    if (!result.rows[0])
      throw new ApiError(404, "NOT_FOUND", "Không tìm thấy lịch chăm sóc.");
    if (result.rows[0].status !== "PENDING")
      fail("Lịch đã hoàn thành hoặc đã hủy.");
    await animal(c, result.rows[0].animal_id);
    return result.rows[0];
  }
  app.patch("/api/care-tasks/:id", care, async (r) => {
    const b = careBody.omit({ animalId: true }).parse(r.body);
    return write(r, b, async (c) => {
      const t = await pending(c, idOf(r));
      const a = await animal(c, t.animal_id);
      if (b.dueDate < a.arrival_date) fail("Ngày hẹn phải từ ngày nhập đàn.");
      await c.query(
        "UPDATE care_tasks SET kind=$2,title=$3,due_date=$4,notes=$5 WHERE id=$1",
        [t.id, b.kind, b.title, b.dueDate, b.notes],
      );
      return { ok: true };
    });
  });
  app.post("/api/care-tasks/:id/complete", examine, async (r) => {
    const b = eventBody.extend({ status: health }).parse(r.body);
    return write(
      r,
      b,
      async (c) => {
        const t = await pending(c, idOf(r));
        const a = await animal(c, t.animal_id);
        actualDate(b.date, a.arrival_date);
        await c.query(
          "UPDATE care_tasks SET status='DONE',actual_date=$2 WHERE id=$1",
          [t.id, b.date],
        );
        await c.query(
          "INSERT INTO health_records(animal_id,date,content,status,notes,task_id,actor_id) VALUES($1,$2,$3,$4,$5,$6,$7)",
          [
            t.animal_id,
            b.date,
            t.title,
            b.status,
            b.notes,
            t.id,
            r.account!.id,
          ],
        );
        await updateHealth(c, t.animal_id);
        return { ok: true };
      },
      b.requestId,
    );
  });
  app.post("/api/care-tasks/:id/cancel", care, async (r) =>
    write(r, null, async (c) => {
      await pending(c, idOf(r));
      await c.query("UPDATE care_tasks SET status='CANCELLED' WHERE id=$1", [
        idOf(r),
      ]);
      return { ok: true };
    }),
  );
  app.get("/api/farm/dashboard", read, async (r) => {
    const scope =
      z.object({ speciesIds: speciesFilter }).parse(r.query).speciesIds ?? null;
    const counts = await pool.query(
      `SELECT count(*) FILTER(WHERE a.status='ACTIVE')::int AS "activeAnimals",count(*) FILTER(WHERE a.status='ACTIVE' AND a.health_status='NEEDS_CARE')::int AS "needsCare" FROM animals a JOIN breeds b ON b.id=a.breed_id WHERE ($1::uuid[] IS NULL OR b.species_id=ANY($1))`,
      [scope],
    );
    const pens = await pool.query(
      `SELECT p.id,p.code,p.name,p.capacity,count(a.id)::int AS occupied FROM pens p LEFT JOIN animals a ON a.pen_id=p.id AND a.status='ACTIVE' WHERE p.active GROUP BY p.id ORDER BY p.code`,
    );
    const tasks = await pool.query(
      `${careSelect} WHERE t.status='PENDING' AND t.due_date<=$1::date+7 AND ($2::uuid[] IS NULL OR a.breed_id IN (SELECT id FROM breeds WHERE species_id=ANY($2))) ORDER BY t.due_date,t.id LIMIT 20`,
      [today(), scope],
    );
    const due = await pool.query(
      "SELECT count(*) FILTER(WHERE t.due_date=$1)::int AS due,count(*) FILTER(WHERE t.due_date<$1)::int AS overdue FROM care_tasks t JOIN animals a ON a.id=t.animal_id JOIN breeds b ON b.id=a.breed_id WHERE t.status='PENDING' AND ($2::uuid[] IS NULL OR b.species_id=ANY($2))",
      [today(), scope],
    );
    const low = await pool.query(
      `SELECT f.id,f.code,f.name,f.low_stock::float8 AS "lowStock",COALESCE(sum(CASE WHEN e.cancelled_at IS NULL THEN CASE WHEN e.kind='IN' THEN e.quantity ELSE -e.quantity END ELSE 0 END),0)::float8 AS stock FROM feeds f LEFT JOIN stock_entries e ON e.feed_id=f.id WHERE f.active GROUP BY f.id HAVING COALESCE(sum(CASE WHEN e.cancelled_at IS NULL THEN CASE WHEN e.kind='IN' THEN e.quantity ELSE -e.quantity END ELSE 0 END),0)<=f.low_stock ORDER BY f.name`,
    );
    return {
      ...counts.rows[0],
      ...due.rows[0],
      activePens: pens.rowCount,
      fullPens: pens.rows.filter((p) => p.occupied >= p.capacity),
      tasks: tasks.rows,
      today: today(),
      lowStockFeeds: low.rows,
      ...(["ADMIN", "ACCOUNTANT"].includes(r.account!.role)
        ? {
            finance: await financeTotals(
              pool,
              today().slice(0, 7) + "-01",
              today(),
            ),
            financeMonthly: await monthlyFinance(pool, today()),
          }
        : {}),
    };
  });
}
