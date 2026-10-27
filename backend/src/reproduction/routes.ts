import type { FastifyInstance, FastifyRequest } from "fastify";
import type { Pool, PoolClient } from "pg";
import { createHash } from "node:crypto";
import { z } from "zod";
import { transaction } from "../database.js";
import { ApiError } from "../auth/service.js";
import { suggestCode } from "../codes.js";
import { animal, actualDate, date } from "../farm/routes.js";

const uuid = z.string().uuid();
const mode = z.enum(["LIVE_BIRTH", "EGGS", "UNSPECIFIED"]);
const eventBody = z
  .object({
    requestId: uuid,
    date,
    quantity: z.number().int().min(1).max(1000),
    notes: z.string().trim().max(2000).default(""),
  })
  .strict();
const conflict = (message: string, code = "REPRODUCTION_CONFLICT"): never => {
  throw new ApiError(409, code, message);
};

export async function registerReproductionRoutes(
  app: FastifyInstance,
  pool: Pool,
  hooks: {
    authenticate: (r: FastifyRequest) => Promise<void>;
    operate: (r: FastifyRequest) => Promise<void>;
    admin: (r: FastifyRequest) => Promise<void>;
  },
) {
  const idOf = (r: FastifyRequest) => z.object({ id: uuid }).parse(r.params).id;
  async function write<T>(
    r: FastifyRequest,
    body: { requestId: string },
    action: (c: PoolClient) => Promise<T>,
  ) {
    return transaction(pool, async (c) => {
      await c.query("SELECT pg_advisory_xact_lock(73201003)");
      const digest = createHash("sha256")
        .update(JSON.stringify([r.method, r.url, body]))
        .digest("hex");
      const previous = await c.query(
        "SELECT digest,result FROM farm_operations WHERE actor_id=$1 AND request_id=$2",
        [r.account!.id, body.requestId],
      );
      if (previous.rowCount) {
        if (previous.rows[0].digest !== digest)
          conflict("Mã yêu cầu đã được dùng với nội dung khác.");
        return previous.rows[0].result as T;
      }
      const result = await action(c);
      await c.query(
        "INSERT INTO farm_operations(actor_id,request_id,digest,result) VALUES($1,$2,$3,$4)",
        [r.account!.id, body.requestId, digest, JSON.stringify(result)],
      );
      return result;
    });
  }
  async function parent(
    c: PoolClient,
    id: string,
    expected: "LIVE_BIRTH" | "EGGS",
    active = true,
  ) {
    const mother = await animal(c, id, active);
    if (mother.gender !== "FEMALE")
      conflict(
        "Chỉ ghi sinh sản cho vật nuôi có giới tính cái.",
        "FEMALE_REQUIRED",
      );
    const breed = (
      await c.query(
        "SELECT b.species_id,s.name,s.reproduction_mode FROM breeds b JOIN species s ON s.id=b.species_id WHERE b.id=$1",
        [mother.breed_id],
      )
    ).rows[0];
    if (breed.reproduction_mode === "UNSPECIFIED")
      conflict(
        "Chủ trang trại cần chọn hình thức sinh sản của loài trước.",
        "REPRODUCTION_MODE_REQUIRED",
      );
    if (breed.reproduction_mode !== expected)
      conflict(
        expected === "EGGS"
          ? "Loài này đang được cấu hình sinh con, không ghi trứng."
          : "Loài này đang được cấu hình đẻ trứng, không ghi sinh con.",
        "REPRODUCTION_MODE_MISMATCH",
      );
    return { mother, breed };
  }
  async function room(c: PoolClient, penId: string, quantity: number) {
    const pen = (
      await c.query(
        "SELECT id,name,capacity,active FROM pens WHERE id=$1 FOR UPDATE",
        [penId],
      )
    ).rows[0];
    if (!pen?.active)
      conflict(
        "Chuồng mặc định đã ngừng sử dụng. Chủ trang trại cần mở lại chuồng hoặc chuyển mẹ trước khi tạo con non.",
        "PEN_INACTIVE",
      );
    const count = (
      await c.query(
        "SELECT count(*)::int AS n FROM animals WHERE pen_id=$1 AND status='ACTIVE'",
        [penId],
      )
    ).rows[0].n as number;
    if (count + quantity > pen.capacity)
      conflict(
        `Chuồng của mẹ chỉ còn ${Math.max(0, pen.capacity - count)} chỗ, chưa đủ cho ${quantity} con. Điều chỉnh sức chứa hoặc chuyển mẹ trước khi ghi nhận.`,
        "PEN_FULL",
      );
    return pen;
  }
  async function offspring(
    c: PoolClient,
    mother: Record<string, any>,
    breedId: string,
    eventId: string,
    value: z.infer<typeof eventBody>,
    farmId: string,
  ) {
    const species = (
      await c.query(
        "SELECT s.name FROM breeds b JOIN species s ON s.id=b.species_id WHERE b.id=$1",
        [breedId],
      )
    ).rows[0].name as string;
    const children = [];
    for (let i = 0; i < value.quantity; i++) {
      const code = await suggestCode(c, "animals", species, farmId);
      const child = (
        await c.query(
          `INSERT INTO animals(code,name,breed_id,gender,birth_date,arrival_date,origin,pen_id,mother_id,birth_event_id)
        VALUES($1,$2,$3,'UNKNOWN',$4,$4,'Sinh tại trang trại',$5,$6,$7)
        RETURNING id,code,name,pen_id AS "penId",mother_id AS "motherId",birth_date AS "birthDate"`,
          [
            code,
            `Con của ${mother.code}`,
            breedId,
            value.date,
            mother.pen_id,
            mother.id,
            eventId,
          ],
        )
      ).rows[0];
      children.push(child);
    }
    return children;
  }
  app.patch(
    "/api/farm/species/:id/reproduction-mode",
    { preHandler: hooks.admin },
    async (r) => {
      const body = z.object({ mode }).strict().parse(r.body);
      return transaction(pool, async (c) => {
        await c.query("SELECT pg_advisory_xact_lock(73201003)");
        const current = (await c.query("SELECT reproduction_mode FROM species WHERE id=$1 FOR UPDATE", [idOf(r)])).rows[0];
        if (current && current.reproduction_mode !== body.mode) {
          const used = await c.query("SELECT 1 FROM reproduction_events e JOIN breeds b ON b.id=e.breed_id WHERE b.species_id=$1 LIMIT 1", [idOf(r)]);
          if (used.rowCount) conflict("Loài đã có lịch sử sinh sản; không thể đổi hình thức sinh sản.");
        }
        const result = await c.query(
          'UPDATE species SET reproduction_mode=$2 WHERE id=$1 RETURNING id,reproduction_mode AS "reproductionMode"',
          [idOf(r), body.mode],
        );
        if (!result.rowCount)
          throw new ApiError(404, "NOT_FOUND", "Không tìm thấy loài.");
        return { species: result.rows[0] };
      });
    },
  );
  app.get(
    "/api/animals/:id/reproduction",
    { preHandler: hooks.authenticate },
    async (r) => {
      const id = idOf(r);
      const query = z
        .object({
          page: z.coerce.number().int().min(1).max(100000).default(1),
          pageSize: z.coerce.number().int().min(1).max(100).default(20),
        })
        .parse(r.query);
      return transaction(pool, async (c) => {
        const a = await animal(c, id, false);
        const species = (
          await c.query(
            "SELECT s.id,s.name,s.reproduction_mode AS mode FROM breeds b JOIN species s ON s.id=b.species_id WHERE b.id=$1",
            [a.breed_id],
          )
        ).rows[0];
        const mother = a.mother_id
          ? (
              await c.query(
                'SELECT id,code,name,status,pen_id AS "penId" FROM animals WHERE id=$1',
                [a.mother_id],
              )
            ).rows[0]
          : null;
        const totals = (
          await c.query(
            `SELECT count(*)::int AS "eventTotal",COALESCE(sum(quantity) FILTER(WHERE kind='LIVE_BIRTH'),0)::int AS "bornCount",
        COALESCE(sum(quantity) FILTER(WHERE kind='EGG_COLLECTION'),0)::bigint::text AS "eggCount",COALESCE(sum(quantity) FILTER(WHERE kind='HATCH'),0)::bigint::text AS "hatchedCount" FROM reproduction_events WHERE mother_id=$1`,
            [id],
          )
        ).rows[0];
        const childTotal = (
          await c.query(
            "SELECT count(*)::int AS n FROM animals WHERE mother_id=$1",
            [id],
          )
        ).rows[0].n;
        const events = await c.query(
          `SELECT e.id,e.kind,e.date,e.quantity,e.notes,e.collection_id AS "collectionId",e.pen_id AS "penId",p.name AS "penName",u.name AS "actorName",e.created_at AS "createdAt",
        COALESCE((SELECT sum(h.quantity) FROM reproduction_events h WHERE h.collection_id=e.id),0)::int AS "hatchedCount"
        FROM reproduction_events e JOIN pens p ON p.id=e.pen_id JOIN public.users u ON u.id=e.actor_id WHERE e.mother_id=$1 ORDER BY e.date DESC,e.created_at DESC,e.id LIMIT $2 OFFSET $3`,
          [id, query.pageSize, (query.page - 1) * query.pageSize],
        );
        const children = await c.query(
          `SELECT a.id,a.code,a.name,a.gender,a.status,a.birth_date AS "birthDate",a.pen_id AS "penId",p.name AS "penName",s.name AS "speciesName" FROM animals a JOIN pens p ON p.id=a.pen_id JOIN breeds b ON b.id=a.breed_id JOIN species s ON s.id=b.species_id WHERE a.mother_id=$1 ORDER BY a.birth_date DESC,a.code,a.id LIMIT $2 OFFSET $3`,
          [id, query.pageSize, (query.page - 1) * query.pageSize],
        );
        return {
          species,
          mother,
          events: events.rows,
          children: children.rows,
          summary: {
            ...totals,
            eggCount: Number(totals.eggCount),
            hatchedCount: Number(totals.hatchedCount),
            childTotal,
          },
          ...query,
        };
      });
    },
  );
  app.post(
    "/api/animals/:id/reproduction/birth",
    { preHandler: hooks.operate },
    async (r) => {
      const body = eventBody.parse(r.body);
      return write(r, body, async (c) => {
        const { mother } = await parent(c, idOf(r), "LIVE_BIRTH");
        actualDate(body.date, mother.arrival_date);
        await room(c, mother.pen_id, body.quantity);
        const event = (
          await c.query(
            `INSERT INTO reproduction_events(mother_id,kind,date,quantity,breed_id,pen_id,notes,actor_id) VALUES($1,'LIVE_BIRTH',$2,$3,$4,$5,$6,$7) RETURNING id`,
            [
              mother.id,
              body.date,
              body.quantity,
              mother.breed_id,
              mother.pen_id,
              body.notes,
              r.account!.id,
            ],
          )
        ).rows[0];
        return {
          event,
          children: await offspring(
            c,
            mother,
            mother.breed_id,
            event.id,
            body,
            r.account!.farmId,
          ),
        };
      });
    },
  );
  app.post(
    "/api/animals/:id/reproduction/eggs",
    { preHandler: hooks.operate },
    async (r) => {
      const body = eventBody
        .extend({ quantity: z.number().int().min(1).max(1000000) })
        .parse(r.body);
      return write(r, body, async (c) => {
        const { mother } = await parent(c, idOf(r), "EGGS");
        actualDate(body.date, mother.arrival_date);
        const event = (
          await c.query(
            `INSERT INTO reproduction_events(mother_id,kind,date,quantity,breed_id,pen_id,notes,actor_id) VALUES($1,'EGG_COLLECTION',$2,$3,$4,$5,$6,$7) RETURNING id`,
            [
              mother.id,
              body.date,
              body.quantity,
              mother.breed_id,
              mother.pen_id,
              body.notes,
              r.account!.id,
            ],
          )
        ).rows[0];
        return { event };
      });
    },
  );
  app.post(
    "/api/animals/:id/reproduction/hatch",
    { preHandler: hooks.operate },
    async (r) => {
      const body = eventBody.extend({ collectionId: uuid }).parse(r.body);
      return write(r, body, async (c) => {
        const { mother } = await parent(c, idOf(r), "EGGS", false);
        const collection = (
          await c.query(
            "SELECT * FROM reproduction_events WHERE id=$1 AND mother_id=$2 AND kind='EGG_COLLECTION' FOR UPDATE",
            [body.collectionId, mother.id],
          )
        ).rows[0];
        if (!collection)
          throw new ApiError(
            404,
            "NOT_FOUND",
            "Không tìm thấy lần ghi trứng của mẹ này.",
          );
        actualDate(body.date, collection.date);
        const used = Number(
          (
            await c.query(
              "SELECT COALESCE(sum(quantity),0)::text AS n FROM reproduction_events WHERE collection_id=$1",
              [collection.id],
            )
          ).rows[0].n,
        );
        if (body.quantity > collection.quantity - used)
          conflict(
            `Lần ghi này chỉ còn ${collection.quantity - used} trứng chưa ghi nở.`,
            "EGGS_EXCEEDED",
          );
        await room(c, mother.pen_id, body.quantity);
        const event = (
          await c.query(
            `INSERT INTO reproduction_events(mother_id,kind,date,quantity,collection_id,breed_id,pen_id,notes,actor_id) VALUES($1,'HATCH',$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
            [
              mother.id,
              body.date,
              body.quantity,
              collection.id,
              collection.breed_id,
              mother.pen_id,
              body.notes,
              r.account!.id,
            ],
          )
        ).rows[0];
        return {
          event,
          children: await offspring(
            c,
            mother,
            collection.breed_id,
            event.id,
            body,
            r.account!.farmId,
          ),
        };
      });
    },
  );
}
