import type { Pool, PoolClient } from "pg";

export async function farmSpecies(pool: Pool | PoolClient, farmId: string) {
  const result = await pool.query<{
    ownerId: string;
    configured: boolean;
    speciesIds: string[];
  }>(
    `SELECT u.id AS "ownerId",coalesce(p.configured,false) AS configured,
      coalesce(array_agg(s.species_id) FILTER (WHERE s.species_id IS NOT NULL),'{}'::uuid[]) AS "speciesIds"
      FROM public.users u LEFT JOIN user_species_preferences p ON p.user_id=u.id
      LEFT JOIN user_species s ON s.user_id=u.id
      WHERE u.farm_id=$1 AND u.role='ADMIN' GROUP BY u.id,p.configured ORDER BY u.id LIMIT 1`,
    [farmId],
  );
  return (
    result.rows[0] ?? { ownerId: undefined, configured: false, speciesIds: [] }
  );
}
