import { createHash } from "node:crypto";
import type { FastifyInstance, FastifyRequest } from "fastify";
import type { Pool, PoolClient } from "pg";
import { z } from "zod";
import { transaction } from "../database.js";
import { ApiError } from "../auth/service.js";
import { today } from "../farm/routes.js";
import { auditFinanceEntry } from "../finance/audit.js";
const uuid = z.string().uuid();
const text = z.string().trim().min(1).max(100);
const notes = z.string().trim().max(2000).default("");
const quantity = z
  .number()
  .finite()
  .positive()
  .max(100000000)
  .refine(
    (v) => Math.abs(v * 1000 - Math.round(v * 1000)) < 1e-5,
    "Tối đa 3 chữ số thập phân.",
  );
const date = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine(
    (v) =>
      v >= "1900-01-01" &&
      v <= today() &&
      !Number.isNaN(Date.parse(v)) &&
      new Date(v).toISOString().slice(0, 10) === v,
    "Ngày thực tế không được nằm trong tương lai.",
  );
const feedBody = z
  .object({
    code: text,
    name: text,
    lowStock: z
      .number()
      .finite()
      .min(0)
      .max(100000000)
      .refine((v) => Math.abs(v * 1000 - Math.round(v * 1000)) < 1e-5),
    active: z.boolean().default(true),
    notes,
  })
  .strict();
const feedSelect = `SELECT f.id,f.code,f.name,f.low_stock::float8 AS "lowStock",f.active,f.notes,COALESCE(sum(CASE WHEN e.cancelled_at IS NULL THEN CASE WHEN e.kind='IN' THEN e.quantity ELSE -e.quantity END ELSE 0 END),0)::float8 AS stock FROM feeds f LEFT JOIN stock_entries e ON e.feed_id=f.id`;
const stockSelect = `SELECT e.id,e.feed_id AS "feedId",f.code AS "feedCode",f.name AS "feedName",e.kind,e.date,e.quantity::float8 AS quantity,e.pen_id AS "penId",p.name AS "penName",e.notes,u.name AS "actorName",e.created_at AS "createdAt",e.cancelled_at AS "cancelledAt",e.cancel_reason AS "cancelReason",cu.name AS "cancelledByName",fe.amount::text AS amount,fe.id AS "financeEntryId" FROM stock_entries e JOIN feeds f ON f.id=e.feed_id JOIN public.users u ON u.id=e.actor_id LEFT JOIN pens p ON p.id=e.pen_id LEFT JOIN public.users cu ON cu.id=e.cancelled_by LEFT JOIN finance_entries fe ON fe.stock_entry_id=e.id`;
const conflict = (message: string): never => {
  throw new ApiError(409, "STOCK_CONFLICT", message);
};
async function balance(c: PoolClient, feedId: string) {
  const r = await c.query(
    "SELECT COALESCE(sum(CASE WHEN kind='IN' THEN quantity ELSE -quantity END),0)::numeric AS stock FROM stock_entries WHERE feed_id=$1 AND cancelled_at IS NULL",
    [feedId],
  );
  return Number(r.rows[0].stock);
}
export async function registerInventoryRoutes(
  app: FastifyInstance,
  pool: Pool,
  hooks: {
    authenticate: (r: FastifyRequest) => Promise<void>;
    admin: (r: FastifyRequest) => Promise<void>;
    operate: (r: FastifyRequest) => Promise<void>;
  },
) {
  const read = { preHandler: hooks.authenticate },
    admin = { preHandler: hooks.admin },
    operate = { preHandler: hooks.operate };
  const id = (r: FastifyRequest) => z.object({ id: uuid }).parse(r.params).id;
  async function write<T>(
    r: FastifyRequest,
    b: unknown,
    action: (c: PoolClient) => Promise<T>,
    requestId?: string,
  ): Promise<T> {
    return transaction(pool, async (c) => {
      await c.query("SELECT pg_advisory_xact_lock(73201003)");
      const digest = createHash("sha256")
        .update(JSON.stringify([r.method, r.url, b]))
        .digest("hex");
      if (requestId) {
        const old = await c.query(
          "SELECT digest,result FROM farm_operations WHERE actor_id=$1 AND request_id=$2",
          [r.account!.id, requestId],
        );
        if (old.rows[0]) {
          if (old.rows[0].digest !== digest)
            conflict("Mã yêu cầu đã được dùng với nội dung khác.");
          return old.rows[0].result as T;
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
  app.get("/api/feeds", read, async () => {
    const r = await pool.query(
      `${feedSelect} GROUP BY f.id ORDER BY f.name,f.id`,
    );
    return { feeds: r.rows };
  });
  app.post("/api/feeds", admin, async (r) => {
    const b = feedBody.parse(r.body);
    return write(r, b, async (c) => ({
      feed: (
        await c.query(
          "INSERT INTO feeds(code,name,low_stock,active,notes) VALUES($1,$2,$3,$4,$5) RETURNING id",
          [b.code, b.name, b.lowStock, b.active, b.notes],
        )
      ).rows[0],
    }));
  });
  app.patch("/api/feeds/:id", admin, async (r) => {
    const b = feedBody.parse(r.body);
    return write(r, b, async (c) => {
      const feed = await c.query("SELECT * FROM feeds WHERE id=$1 FOR UPDATE", [
        id(r),
      ]);
      if (!feed.rowCount)
        throw new ApiError(404, "NOT_FOUND", "Không tìm thấy thức ăn.");
      if (!b.active && (await balance(c, id(r))) > 0)
        conflict("Thức ăn còn tồn kho; chưa thể ngừng sử dụng.");
      await c.query(
        "UPDATE feeds SET code=$2,name=$3,low_stock=$4,active=$5,notes=$6 WHERE id=$1",
        [id(r), b.code, b.name, b.lowStock, b.active, b.notes],
      );
      return { ok: true };
    });
  });
  app.delete("/api/feeds/:id", admin, async (r) =>
    write(r, null, async (c) => {
      const result = await c.query(
        "DELETE FROM feeds WHERE id=$1 RETURNING id",
        [id(r)],
      );
      if (!result.rowCount)
        throw new ApiError(404, "NOT_FOUND", "Không tìm thấy thức ăn.");
      return { ok: true };
    }),
  );
  app.get("/api/stock-entries", operate, async (r) => {
    const q = z
      .object({
        page: z.coerce.number().int().min(1).max(100000).default(1),
        pageSize: z.coerce.number().int().min(1).max(100).default(20),
        feedId: uuid.optional(),
        kind: z.enum(["IN", "OUT"]).optional(),
        from: date.optional(),
        to: date.optional(),
        status: z.enum(["VALID", "CANCELLED"]).optional(),
      })
      .parse(r.query);
    if (q.from && q.to && q.from > q.to)
      throw new ApiError(
        400,
        "INVALID_RANGE",
        "Ngày bắt đầu phải trước ngày kết thúc.",
      );
    const args = [
      q.feedId ?? null,
      q.kind ?? null,
      q.from ?? null,
      q.to ?? null,
      q.status ?? null,
    ];
    const where = ` WHERE ($1::uuid IS NULL OR e.feed_id=$1) AND ($2::text IS NULL OR e.kind=$2) AND ($3::date IS NULL OR e.date>=$3) AND ($4::date IS NULL OR e.date<=$4) AND ($5::text IS NULL OR ($5='VALID' AND e.cancelled_at IS NULL) OR ($5='CANCELLED' AND e.cancelled_at IS NOT NULL))`;
    const [rows, total] = await Promise.all([
      pool.query(
        `${stockSelect}${where} ORDER BY e.date DESC,e.created_at DESC,e.id LIMIT $6 OFFSET $7`,
        [...args, q.pageSize, (q.page - 1) * q.pageSize],
      ),
      pool.query(
        `SELECT count(*)::int AS n FROM stock_entries e${where}`,
        args,
      ),
    ]);
    return {
      entries: rows.rows,
      total: total.rows[0].n,
      page: q.page,
      pageSize: q.pageSize,
    };
  });
  app.post("/api/stock-entries", operate, async (r) => {
    const b = z
      .object({
        requestId: uuid,
        feedId: uuid,
        kind: z.enum(["IN", "OUT"]),
        date,
        quantity,
        amount: z.number().int().positive().max(1000000000000).optional(),
        penId: uuid.nullable().default(null),
        notes,
      })
      .strict()
      .parse(r.body);
    if (b.kind === "OUT" && b.amount !== undefined)
      throw new ApiError(
        400,
        "INVALID_AMOUNT",
        "Chỉ phiếu nhập kho được ghi tiền mua thức ăn.",
      );
    if (b.kind === "IN" && b.penId)
      throw new ApiError(
        400,
        "INVALID_PEN",
        "Chỉ phiếu xuất mới liên kết chuồng.",
      );
    return write(
      r,
      b,
      async (c) => {
        const feed = await c.query(
          "SELECT * FROM feeds WHERE id=$1 FOR UPDATE",
          [b.feedId],
        );
        if (!feed.rows[0]?.active)
          conflict("Thức ăn không tồn tại hoặc đã ngừng sử dụng.");
        if (
          b.kind === "OUT" &&
          (await balance(c, b.feedId)) * 1000 + 1e-5 <
            Math.round(b.quantity * 1000)
        )
          conflict("Số lượng xuất vượt tồn kho hiện tại.");
        if (b.penId) {
          const pen = await c.query("SELECT active FROM pens WHERE id=$1", [
            b.penId,
          ]);
          if (!pen.rows[0]?.active)
            conflict("Chuồng không tồn tại hoặc đã ngừng sử dụng.");
        }
        const result = await c.query(
          "INSERT INTO stock_entries(feed_id,kind,date,quantity,pen_id,notes,actor_id) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING id",
          [
            b.feedId,
            b.kind,
            b.date,
            b.quantity,
            b.penId,
            b.notes,
            r.account!.id,
          ],
        );
        if (b.amount !== undefined) {
          const expense = await c.query<{ id: string }>(
            "INSERT INTO finance_entries(date,kind,category,amount,content,stock_entry_id,actor_id) VALUES($1,'OUT','FEED',$2,$3,$4,$5) RETURNING id",
            [
              b.date,
              b.amount,
              `Mua thức ăn nhập kho: ${feed.rows[0].name}`,
              result.rows[0].id,
              r.account!.id,
            ],
          );
          await auditFinanceEntry(
            c,
            expense.rows[0]!.id,
            "CREATE",
            r.account!.id,
            "Nhập kho thức ăn",
          );
        }
        return { entry: result.rows[0] };
      },
      b.requestId,
    );
  });
  app.post("/api/stock-entries/:id/cancel", admin, async (r) => {
    const b = z
      .object({ requestId: uuid, reason: z.string().trim().min(1).max(1000) })
      .strict()
      .parse(r.body);
    return write(
      r,
      b,
      async (c) => {
        const result = await c.query(
          "SELECT * FROM stock_entries WHERE id=$1 FOR UPDATE",
          [id(r)],
        );
        const entry = result.rows[0];
        if (!entry)
          throw new ApiError(404, "NOT_FOUND", "Không tìm thấy phiếu.");
        if (entry.cancelled_at) conflict("Phiếu đã được hủy.");
        if (
          entry.kind === "IN" &&
          (await balance(c, entry.feed_id)) * 1000 + 1e-5 <
            Math.round(Number(entry.quantity) * 1000)
        )
          conflict("Không thể hủy phiếu nhập vì sẽ làm âm tồn kho.");
        await c.query(
          "UPDATE stock_entries SET cancelled_at=clock_timestamp(),cancelled_by=$2,cancel_reason=$3 WHERE id=$1",
          [entry.id, r.account!.id, b.reason],
        );
        const expense = await c.query(
          "SELECT * FROM finance_entries WHERE stock_entry_id=$1 FOR UPDATE",
          [entry.id],
        );
        if (expense.rows[0]) {
          const old = expense.rows[0];
          if (old.cancelled_at)
            conflict("Khoản chi của phiếu đã bị hủy; hãy kiểm tra dữ liệu.");
          await c.query(
            "UPDATE finance_entries SET cancelled_at=clock_timestamp(),cancelled_by=$2,cancel_reason=$3,updated_at=clock_timestamp() WHERE id=$1",
            [old.id, r.account!.id, b.reason],
          );
          await auditFinanceEntry(
            c,
            old.id,
            "CANCEL",
            r.account!.id,
            b.reason,
            old,
          );
        }
        return { ok: true };
      },
      b.requestId,
    );
  });
  app.get("/api/farm/preferences", read, async (r) => {
    const [pref, selected] = await Promise.all([
      pool.query(
        "SELECT configured FROM user_species_preferences WHERE user_id=$1",
        [r.account!.id],
      ),
      pool.query(
        "SELECT species_id AS id FROM user_species WHERE user_id=$1 ORDER BY species_id",
        [r.account!.id],
      ),
    ]);
    return {
      configured: pref.rows[0]?.configured ?? false,
      speciesIds: selected.rows.map((s) => s.id),
    };
  });
  app.patch("/api/farm/preferences", read, async (r) => {
    const b = z
      .object({
        speciesIds: z
          .array(uuid)
          .max(100)
          .refine((ids) => new Set(ids).size === ids.length, "Loài bị trùng."),
      })
      .strict()
      .parse(r.body);
    return write(r, b, async (c) => {
      const valid = await c.query(
        "SELECT id FROM species WHERE id=ANY($1::uuid[])",
        [b.speciesIds],
      );
      if (valid.rowCount !== b.speciesIds.length)
        conflict("Một loài đã bị xóa; hãy tải lại danh sách.");
      if (r.account!.role === "ADMIN") {
        if (!b.speciesIds.length)
          throw new ApiError(
            400,
            "SPECIES_REQUIRED",
            "Hãy chọn ít nhất một loài đang nuôi.",
          );
        const used = await c.query(
          "SELECT 1 FROM animals a JOIN breeds b ON b.id=a.breed_id WHERE NOT b.species_id=ANY($1::uuid[]) LIMIT 1",
          [b.speciesIds],
        );
        if (used.rowCount) conflict("Không thể bỏ loài đã có hồ sơ vật nuôi.");
      }
      await c.query(
        "INSERT INTO user_species_preferences(user_id,configured) VALUES($1,true) ON CONFLICT(user_id) DO UPDATE SET configured=true",
        [r.account!.id],
      );
      await c.query("DELETE FROM user_species WHERE user_id=$1", [
        r.account!.id,
      ]);
      await c.query(
        "INSERT INTO user_species(user_id,species_id) SELECT $1,unnest($2::uuid[])",
        [r.account!.id, b.speciesIds],
      );
      return { ok: true };
    });
  });
}
