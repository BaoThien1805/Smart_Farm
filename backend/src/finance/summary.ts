import type { Pool } from "pg";
export async function financeTotals(pool: Pool, from: string, to: string) {
  return (
    await pool.query(
      `SELECT COALESCE(sum(amount) FILTER(WHERE category='ANIMAL_SALE'),0)::text AS "salesRevenue",COALESCE(sum(amount) FILTER(WHERE kind='IN'),0)::text AS income,COALESCE(sum(amount) FILTER(WHERE kind='OUT'),0)::text AS expense,COALESCE(sum(CASE WHEN kind='IN' THEN amount ELSE -amount END),0)::text AS difference FROM finance_entries WHERE cancelled_at IS NULL AND date BETWEEN $1 AND $2`,
      [from, to],
    )
  ).rows[0];
}
export async function monthlyFinance(pool: Pool, to: string) {
  const start = new Date(`${to}T00:00:00Z`);
  start.setUTCDate(1);
  start.setUTCMonth(start.getUTCMonth() - 5);
  const from = start.toISOString().slice(0, 10);
  return (
    await pool.query(
      `WITH months AS (
    SELECT generate_series($1::date,date_trunc('month',$2::date),interval '1 month')::date AS month
  ) SELECT to_char(m.month,'YYYY-MM') AS month,
    COALESCE(sum(e.amount) FILTER(WHERE e.category='ANIMAL_SALE'),0)::text AS "salesRevenue",
    COALESCE(sum(e.amount) FILTER(WHERE e.kind='IN'),0)::text AS income,
    COALESCE(sum(e.amount) FILTER(WHERE e.kind='OUT'),0)::text AS expense,
    COALESCE(sum(CASE WHEN e.kind='IN' THEN e.amount ELSE -e.amount END),0)::text AS difference
  FROM months m LEFT JOIN finance_entries e ON date_trunc('month',e.date)::date=m.month
    AND e.cancelled_at IS NULL AND e.date BETWEEN $1 AND $2
  GROUP BY m.month ORDER BY m.month DESC`,
      [from, to],
    )
  ).rows;
}
