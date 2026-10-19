import type { Pool, PoolClient } from "pg";
import { z } from "zod";
import { ApiError } from "./auth/service.js";

export const codeSchema = z.string().trim().min(1).max(100);
export const codeKind = z.enum([
  "animals",
  "pens",
  "areas",
  "species",
  "breeds",
  "users",
  "feeds",
]);
export type CodeKind = z.infer<typeof codeKind>;
const defaults: Record<CodeKind, string> = {
  animals: "VN",
  pens: "CH",
  areas: "KV",
  species: "L",
  breeds: "G",
  users: "NV",
  feeds: "TA",
};

export function codePrefix(kind: CodeKind, name: string): string {
  if (kind === "users") return "NV";
  const words =
    name
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[đĐ]/g, "D")
      .toUpperCase()
      .match(/[A-Z0-9]+/g) ?? [];
  if (!words.length) return defaults[kind];
  return (
    words.length > 1 ? words.map((word) => word[0]).join("") : words[0]!
  ).slice(0, 8);
}

/** The table identifier is a fixed enum; every user value is a SQL parameter. */
export async function suggestCode(
  db: Pool | PoolClient,
  kind: CodeKind,
  name: string,
  farmId: string,
): Promise<string> {
  const prefix =
    codePrefix(kind, name) +
    (kind === "animals" || kind === "breeds" ? "_" : "-");
  const table = kind === "users" ? "public.users" : kind;
  const result = await db.query<{ next: string }>(
    `SELECT (COALESCE(MAX(substring(code from length($1)+1)::numeric),0)+1)::text AS next
     FROM ${table} WHERE left(upper(code),length($1))=$1
     AND substring(code from length($1)+1) ~ '^[0-9]{1,12}$'
     ${kind === "users" ? "AND farm_id=$2" : ""}`,
    kind === "users" ? [prefix, farmId] : [prefix],
  );
  const next = result.rows[0]!.next;
  if (next.length > 12)
    throw new ApiError(
      409,
      "CODE_LIMIT",
      "Đã hết số thứ tự cho tiền tố mã này.",
    );
  return prefix + next.padStart(2, "0");
}

export const catalogCodesMigration = `
ALTER TABLE areas ADD COLUMN code text CHECK(code IS NULL OR length(trim(code)) BETWEEN 1 AND 100);
ALTER TABLE species ADD COLUMN code text CHECK(code IS NULL OR length(trim(code)) BETWEEN 1 AND 100);
ALTER TABLE breeds ADD COLUMN code text CHECK(code IS NULL OR length(trim(code)) BETWEEN 1 AND 100);
CREATE UNIQUE INDEX areas_code_unique ON areas(upper(code));
CREATE UNIQUE INDEX species_code_unique ON species(upper(code));
CREATE UNIQUE INDEX breeds_code_unique ON breeds(upper(code));
`;
