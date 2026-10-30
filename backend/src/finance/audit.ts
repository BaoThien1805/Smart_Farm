import type { PoolClient } from "pg";

export async function auditFinanceEntry(
  client: PoolClient,
  entryId: string,
  action: "CREATE" | "EDIT" | "CANCEL",
  actorId: string,
  reason: string,
  before: unknown = null,
) {
  await client.query(
    "INSERT INTO finance_audit(entry_id,action,before_data,after_data,reason,actor_id) SELECT id,$2,$3::jsonb,jsonb_set(to_jsonb(e),'{amount}',to_jsonb(e.amount::text)),$4,$5 FROM finance_entries e WHERE id=$1",
    [
      entryId,
      action,
      before === null ? null : JSON.stringify(before),
      reason,
      actorId,
    ],
  );
}
