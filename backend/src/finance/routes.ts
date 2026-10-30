import { createHash } from "node:crypto";
import type { FastifyInstance, FastifyRequest } from "fastify";
import type { Pool, PoolClient } from "pg";
import { z } from "zod";
import { ApiError } from "../auth/service.js";
import { transaction } from "../database.js";
import { animal, actualDate, capacity, date, today } from "../farm/routes.js";
import { auditFinanceEntry as audit } from "./audit.js";

const uuid = z.string().uuid();
const amount = z.number().int().positive().max(1000000000000);
const reason = z.string().trim().min(1).max(1000);
const notes = z.string().trim().max(2000).default("");
const kind = z.enum(["IN", "OUT"]);
const category = z.enum([
  "ANIMAL_SALE",
  "FEED",
  "MEDICINE",
  "ANIMAL_PURCHASE",
  "OTHER",
]);
const manualBody = z
  .object({
    date,
    kind,
    category: category.exclude(["ANIMAL_SALE"]),
    amount,
    content: z.string().trim().min(1).max(500),
  })
  .strict();
const paging = z.object({
  page: z.coerce.number().int().min(1).max(100000).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
  status: z.enum(["VALID", "CANCELLED", "ALL"]).default("VALID"),
});
const range = z
  .object({
    from: date.default(() => today().slice(0, 7) + "-01"),
    to: date.default(today),
    kind: kind.optional(),
    category: category.optional(),
  })
  .refine(
    (b) =>
      b.from <= b.to && Date.parse(b.to) - Date.parse(b.from) <= 730 * 86400000,
    "Khoảng ngày phải đúng thứ tự và tối đa 730 ngày.",
  );
const entrySelect = `SELECT e.id,e.date,e.kind,e.category,e.amount::text,e.content,e.sale_id AS "saleId",e.stock_entry_id AS "stockEntryId",e.created_at AS "createdAt",e.updated_at AS "updatedAt",u.name AS "actorName",e.cancelled_at AS "cancelledAt",e.cancel_reason AS "cancelReason",cu.name AS "cancelledByName" FROM finance_entries e JOIN public.users u ON u.id=e.actor_id LEFT JOIN public.users cu ON cu.id=e.cancelled_by`;
const saleSelect = `SELECT s.id,s.animal_id AS "animalId",a.code AS "animalCode",s.date,s.amount::text,s.buyer,s.notes,u.name AS "actorName",s.created_at AS "createdAt",s.cancelled_at AS "cancelledAt",s.cancel_reason AS "cancelReason",cu.name AS "cancelledByName",s.restore_date AS "restoreDate",p.name AS "restorePenName" FROM sales s JOIN animals a ON a.id=s.animal_id JOIN public.users u ON u.id=s.actor_id LEFT JOIN public.users cu ON cu.id=s.cancelled_by LEFT JOIN pens p ON p.id=s.restore_pen_id`;
function conflict(message: string): never {
  throw new ApiError(409, "FINANCE_CONFLICT", message);
}
export async function registerFinanceRoutes(
  app: FastifyInstance,
  pool: Pool,
  hooks: {
    admin: (r: FastifyRequest) => Promise<void>;
    finance: (r: FastifyRequest) => Promise<void>;
  },
) {
  const admin = { preHandler: hooks.admin };
  const finance = { preHandler: hooks.finance };
  const idOf = (r: FastifyRequest) => z.object({ id: uuid }).parse(r.params).id;
  async function write<T>(
    r: FastifyRequest,
    body: unknown,
    requestId: string,
    action: (c: PoolClient) => Promise<T>,
  ): Promise<T> {
    return transaction(pool, async (c) => {
      await c.query("SELECT pg_advisory_xact_lock(73201003)");
      const digest = createHash("sha256")
        .update(JSON.stringify([r.method, r.url, body]))
        .digest("hex");
      const old = await c.query(
        "SELECT digest,result FROM farm_operations WHERE actor_id=$1 AND request_id=$2",
        [r.account!.id, requestId],
      );
      if (old.rows[0]) {
        if (old.rows[0].digest !== digest)
          conflict("Mã yêu cầu đã dùng với nội dung khác.");
        return old.rows[0].result as T;
      }
      const result = await action(c);
      await c.query(
        "INSERT INTO farm_operations(actor_id,request_id,digest,result) VALUES($1,$2,$3,$4)",
        [r.account!.id, requestId, digest, JSON.stringify(result)],
      );
      return result;
    });
  }
  async function editable(c: PoolClient, id: string) {
    const e = (
      await c.query("SELECT * FROM finance_entries WHERE id=$1 FOR UPDATE", [
        id,
      ])
    ).rows[0];
    if (!e)
      throw new ApiError(404, "NOT_FOUND", "Không tìm thấy khoản thu chi.");
    if (e.sale_id)
      conflict("Khoản thu bán vật nuôi chỉ thay đổi qua thao tác hủy bán.");
    if (e.stock_entry_id)
      conflict(
        "Khoản chi mua thức ăn chỉ thay đổi qua thao tác hủy phiếu nhập kho.",
      );
    if (e.cancelled_at) conflict("Khoản thu chi đã hủy.");
    return e;
  }
  app.get("/api/finance/entries", finance, async (r) => {
    const q = paging.parse(r.query),
      f = range.parse(r.query);
    const values = [f.from, f.to, f.kind ?? null, f.category ?? null, q.status];
    const where = `WHERE e.date BETWEEN $1 AND $2 AND ($3::text IS NULL OR e.kind=$3) AND ($4::text IS NULL OR e.category=$4) AND ($5='ALL' OR ($5='VALID' AND e.cancelled_at IS NULL) OR ($5='CANCELLED' AND e.cancelled_at IS NOT NULL))`;
    const total = await pool.query(
      `SELECT count(*)::int AS total FROM finance_entries e ${where}`,
      values,
    );
    const rows = await pool.query(
      `${entrySelect} ${where} ORDER BY e.date DESC,e.created_at DESC,e.id LIMIT $6 OFFSET $7`,
      [...values, q.pageSize, (q.page - 1) * q.pageSize],
    );
    return { entries: rows.rows, total: total.rows[0].total, ...q };
  });
  app.post("/api/finance/entries", finance, async (r) => {
    const b = manualBody.extend({ requestId: uuid }).parse(r.body);
    actualDate(b.date, "1900-01-01");
    return write(r, b, b.requestId, async (c) => {
      const e = (
        await c.query(
          "INSERT INTO finance_entries(date,kind,category,amount,content,actor_id) VALUES($1,$2,$3,$4,$5,$6) RETURNING id",
          [b.date, b.kind, b.category, b.amount, b.content, r.account!.id],
        )
      ).rows[0];
      await audit(c, e.id, "CREATE", r.account!.id, "Ghi thu chi");
      return { entry: e };
    });
  });
  app.patch("/api/finance/entries/:id", finance, async (r) => {
    const b = manualBody.extend({ requestId: uuid, reason }).parse(r.body);
    actualDate(b.date, "1900-01-01");
    return write(r, b, b.requestId, async (c) => {
      const id = idOf(r),
        old = await editable(c, id);
      await c.query(
        "UPDATE finance_entries SET date=$2,kind=$3,category=$4,amount=$5,content=$6,updated_at=clock_timestamp() WHERE id=$1",
        [id, b.date, b.kind, b.category, b.amount, b.content],
      );
      await audit(c, id, "EDIT", r.account!.id, b.reason, old);
      return { ok: true };
    });
  });
  app.post("/api/finance/entries/:id/cancel", finance, async (r) => {
    const b = z.object({ requestId: uuid, reason }).strict().parse(r.body);
    return write(r, b, b.requestId, async (c) => {
      const id = idOf(r),
        old = await editable(c, id);
      await c.query(
        "UPDATE finance_entries SET cancelled_at=clock_timestamp(),cancelled_by=$2,cancel_reason=$3,updated_at=clock_timestamp() WHERE id=$1",
        [id, r.account!.id, b.reason],
      );
      await audit(c, id, "CANCEL", r.account!.id, b.reason, old);
      return { ok: true };
    });
  });
  app.get("/api/finance/entries/:id/history", finance, async (r) => {
    const id = idOf(r);
    if (
      !(await pool.query("SELECT id FROM finance_entries WHERE id=$1", [id]))
        .rowCount
    )
      throw new ApiError(404, "NOT_FOUND", "Không tìm thấy khoản thu chi.");
    const rows = await pool.query(
      `SELECT a.id,a.action,a.reason,a.created_at AS "createdAt",u.name AS "actorName",a.before_data AS before,a.after_data AS after FROM finance_audit a JOIN public.users u ON u.id=a.actor_id WHERE a.entry_id=$1 ORDER BY a.created_at,a.id`,
      [id],
    );
    return { history: rows.rows };
  });
  app.get("/api/finance/report", finance, async (r) => {
    const q = range.parse(r.query);
    const data = await pool.query(
      `WITH filtered AS (SELECT date,kind,category,amount FROM finance_entries WHERE cancelled_at IS NULL AND date BETWEEN $1 AND $2 AND ($3::text IS NULL OR kind=$3) AND ($4::text IS NULL OR category=$4)),
      totals AS (SELECT COALESCE(sum(amount) FILTER(WHERE category='ANIMAL_SALE'),0)::text AS "salesRevenue",COALESCE(sum(amount) FILTER(WHERE kind='IN'),0)::text AS income,COALESCE(sum(amount) FILTER(WHERE kind='OUT'),0)::text AS expense,COALESCE(sum(CASE WHEN kind='IN' THEN amount ELSE -amount END),0)::text AS difference FROM filtered),
      months AS (SELECT generate_series(date_trunc('month',$1::date),date_trunc('month',$2::date),interval '1 month')::date AS month),
      monthly AS (SELECT to_char(m.month,'YYYY-MM') AS month,COALESCE(sum(f.amount) FILTER(WHERE f.kind='IN'),0)::text AS income,COALESCE(sum(f.amount) FILTER(WHERE f.kind='OUT'),0)::text AS expense FROM months m LEFT JOIN filtered f ON date_trunc('month',f.date)::date=m.month GROUP BY m.month ORDER BY m.month)
      SELECT (SELECT to_jsonb(t) FROM totals t) AS summary,(SELECT jsonb_agg(to_jsonb(m) ORDER BY m.month) FROM monthly m) AS monthly`,
      [q.from, q.to, q.kind ?? null, q.category ?? null],
    );
    return { ...data.rows[0], from: q.from, to: q.to };
  });
  app.get("/api/sales", finance, async (r) => {
    const q = paging.extend({ animalId: uuid.optional() }).parse(r.query);
    const values = [q.animalId ?? null, q.status];
    const where = `WHERE ($1::uuid IS NULL OR s.animal_id=$1) AND ($2='ALL' OR ($2='VALID' AND s.cancelled_at IS NULL) OR ($2='CANCELLED' AND s.cancelled_at IS NOT NULL))`;
    const total = await pool.query(
      `SELECT count(*)::int AS total FROM sales s ${where}`,
      values,
    );
    const rows = await pool.query(
      `${saleSelect} ${where} ORDER BY s.date DESC,s.created_at DESC,s.id LIMIT $3 OFFSET $4`,
      [...values, q.pageSize, (q.page - 1) * q.pageSize],
    );
    return { sales: rows.rows, total: total.rows[0].total, ...q };
  });
  const saleBody = z
    .object({
      requestId: uuid,
      date,
      amount,
      buyer: z.string().trim().max(200).default(""),
      notes,
    })
    .strict();
  async function sellOne(
    c: PoolClient,
    id: string,
    b: z.infer<typeof saleBody>,
    actorId: string,
  ) {
    const a = await animal(c, id);
    actualDate(b.date, a.arrival_date);
    const latest = await c.query(
      `SELECT max(date)::text AS date FROM (SELECT date FROM weights WHERE animal_id=$1 UNION ALL SELECT date FROM transfers WHERE animal_id=$1 UNION ALL SELECT date FROM health_records WHERE animal_id=$1 UNION ALL SELECT date FROM reproduction_events WHERE mother_id=$1 AND kind IN ('LIVE_BIRTH','EGG_COLLECTION') UNION ALL SELECT restore_date FROM sales WHERE animal_id=$1 AND cancelled_at IS NOT NULL) events`,
      [id],
    );
    if (latest.rows[0].date && b.date < latest.rows[0].date)
      conflict("Ngày bán không thể trước lịch sử đã ghi.");
    const sale = (
      await c.query(
        "INSERT INTO sales(animal_id,date,amount,buyer,notes,actor_id) VALUES($1,$2,$3,$4,$5,$6) RETURNING id",
        [id, b.date, b.amount, b.buyer, b.notes, actorId],
      )
    ).rows[0];
    const entry = (
      await c.query(
        "INSERT INTO finance_entries(date,kind,category,amount,content,sale_id,actor_id) VALUES($1,'IN','ANIMAL_SALE',$2,$3,$4,$5) RETURNING id",
        [b.date, b.amount, `Bán vật nuôi ${a.code}`, sale.id, actorId],
      )
    ).rows[0];
    await audit(c, entry.id, "CREATE", actorId, "Bán vật nuôi");
    await c.query(
      "UPDATE animals SET status='SOLD',ended_date=$2 WHERE id=$1",
      [id, b.date],
    );
    await c.query(
      "UPDATE care_tasks SET status='CANCELLED' WHERE animal_id=$1 AND status='PENDING'",
      [id],
    );
    return { sale, entry };
  }
  app.post("/api/animals/:id/sell", admin, async (r) => {
    const b = saleBody.parse(r.body);
    return write(r, b, b.requestId, (c) =>
      sellOne(c, idOf(r), b, r.account!.id),
    );
  });
  app.post(
    "/api/animals/batch/sell",
    { ...admin, bodyLimit: 131072 },
    async (r) => {
      const b = saleBody
        .omit({ amount: true })
        .extend({
          items: z
            .array(z.object({ animalId: uuid, amount }).strict())
            .min(1)
            .max(1000)
            .refine(
              (items) =>
                new Set(items.map((item) => item.animalId)).size ===
                items.length,
              "Không chọn trùng vật nuôi.",
            )
            .transform((items) =>
              items.sort((a, b) => a.animalId.localeCompare(b.animalId)),
            ),
        })
        .parse(r.body);
      return write(r, b, b.requestId, async (c) => {
        const results = [];
        for (const item of b.items) {
          const result = await sellOne(
            c,
            item.animalId,
            { ...b, amount: item.amount },
            r.account!.id,
          );
          results.push({
            animalId: item.animalId,
            saleId: result.sale.id,
            entryId: result.entry.id,
          });
        }
        return {
          count: results.length,
          sales: results,
          totalAmount: b.items
            .reduce((sum, item) => sum + item.amount, 0)
            .toString(),
        };
      });
    },
  );
  app.post("/api/sales/:id/cancel", admin, async (r) => {
    const b = z
      .object({ requestId: uuid, reason, penId: uuid, date })
      .strict()
      .parse(r.body);
    return write(r, b, b.requestId, async (c) => {
      const id = idOf(r),
        s = (await c.query("SELECT * FROM sales WHERE id=$1 FOR UPDATE", [id]))
          .rows[0];
      if (!s)
        throw new ApiError(404, "NOT_FOUND", "Không tìm thấy giao dịch bán.");
      if (s.cancelled_at) conflict("Giao dịch bán đã hủy.");
      const a = await animal(c, s.animal_id, false);
      if (a.status !== "SOLD") conflict("Vật nuôi không ở trạng thái đã bán.");
      actualDate(b.date, s.date);
      await capacity(c, b.penId);
      const e = (
        await c.query(
          "SELECT * FROM finance_entries WHERE sale_id=$1 FOR UPDATE",
          [id],
        )
      ).rows[0];
      if (!e || e.cancelled_at) conflict("Khoản thu liên kết không hợp lệ.");
      await c.query(
        "UPDATE sales SET cancelled_at=clock_timestamp(),cancelled_by=$2,cancel_reason=$3,restore_date=$4,restore_pen_id=$5 WHERE id=$1",
        [id, r.account!.id, b.reason, b.date, b.penId],
      );
      await c.query(
        "UPDATE finance_entries SET cancelled_at=clock_timestamp(),cancelled_by=$2,cancel_reason=$3,updated_at=clock_timestamp() WHERE id=$1",
        [e.id, r.account!.id, b.reason],
      );
      await audit(c, e.id, "CANCEL", r.account!.id, b.reason, e);
      await c.query(
        "UPDATE animals SET status='ACTIVE',ended_date=NULL,pen_id=$2 WHERE id=$1",
        [a.id, b.penId],
      );
      await c.query(
        "INSERT INTO transfers(animal_id,from_pen_id,to_pen_id,date,notes,actor_id) VALUES($1,$2,$3,$4,$5,$6)",
        [
          a.id,
          a.pen_id,
          b.penId,
          b.date,
          `Khôi phục sau hủy bán: ${b.reason}`,
          r.account!.id,
        ],
      );
      return { ok: true };
    });
  });
}
