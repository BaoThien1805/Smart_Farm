import { suggestCode } from "../codes.js";
import type { Pool } from "pg";
import { z } from "zod";
import { randomUUID } from "node:crypto";
import { createFarmTables, transaction } from "../database.js";
import {
  hashPassword,
  newToken,
  tokenHash,
  verifyPassword,
} from "../security.js";

export class ApiError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}
export type User = {
  id: string;
  email: string;
  name: string;
  role: "ADMIN" | "STAFF" | "VET" | "ACCOUNTANT";
  active: boolean;
  createdAt: Date;
  farmId: string;
  avatarData: string | null;
  code: string | null;
};
type PrivateUser = User & { password_hash: string };
export const emailSchema = z
  .string()
  .trim()
  .email()
  .max(254)
  .transform((value) => value.toLowerCase());
export const passwordSchema = z
  .string()
  .min(12, "Mật khẩu cần ít nhất 12 ký tự.")
  .max(128);
export const publicColumns =
  'id, email, name, code, role, active, farm_id AS "farmId", created_at AS "createdAt", avatar_data AS "avatarData"';
const invalidLogin = () =>
  new ApiError(401, "INVALID_CREDENTIALS", "Email hoặc mật khẩu không đúng.");
const invalidSession = () =>
  new ApiError(
    401,
    "UNAUTHENTICATED",
    "Phiên đã hết hạn. Vui lòng đăng nhập lại.",
  );

export class AuthService {
  private dummyHash: Promise<string>;
  constructor(
    private pool: Pool,
    private sessionHours: number,
  ) {
    this.dummyHash = hashPassword(newToken());
  }

  async register(input: {
    name: string;
    farmName: string;
    email: string;
    password: string;
  }) {
    const passwordHash = await hashPassword(input.password);
    const farmId = randomUUID();
    const schema = "farm_" + farmId.replaceAll("-", "");
    return transaction(this.pool, async (client) => {
      await client.query("SELECT pg_advisory_xact_lock(73201001)");
      await client.query(
        "INSERT INTO farms(id,name,schema_name) VALUES($1,$2,$3)",
        [farmId, input.farmName, schema],
      );
      const result = await client.query<User>(
        `INSERT INTO users(name,email,password_hash,role,farm_id) VALUES($1,$2,$3,'ADMIN',$4) RETURNING ${publicColumns}`,
        [input.name, input.email, passwordHash, farmId],
      );
      await createFarmTables(client, schema);
      const token = newToken();
      const expiresAt = new Date(Date.now() + this.sessionHours * 3600000);
      await client.query(
        "INSERT INTO public.sessions(token_hash,user_id,expires_at) VALUES($1,$2,$3)",
        [tokenHash(token), result.rows[0]!.id, expiresAt],
      );
      return { token, expiresAt, user: result.rows[0]! };
    });
  }

  async login(email: string, password: string) {
    const found = await this.pool.query<PrivateUser>(
      `SELECT ${publicColumns}, password_hash FROM users WHERE email=$1 AND deleted_at IS NULL`,
      [email],
    );
    const user = found.rows[0];
    const valid = await verifyPassword(
      password,
      user?.password_hash ?? (await this.dummyHash),
    );
    if (!user || !valid || !user.active) throw invalidLogin();
    const upgradedHash = user.password_hash.startsWith("scrypt:")
      ? await hashPassword(password)
      : null;
    return transaction(this.pool, async (client) => {
      // Serialize login with account locking/password changes; stale credentials cannot issue a session.
      const locked = await client.query<PrivateUser>(
        `SELECT ${publicColumns}, password_hash FROM users WHERE id=$1 AND deleted_at IS NULL FOR UPDATE`,
        [user.id],
      );
      const current = locked.rows[0];
      if (!current?.active || current.password_hash !== user.password_hash)
        throw invalidLogin();
      if (upgradedHash)
        await client.query("UPDATE users SET password_hash=$1 WHERE id=$2", [
          upgradedHash,
          user.id,
        ]);
      const token = newToken();
      const expiresAt = new Date(Date.now() + this.sessionHours * 3600000);
      await client.query(
        "DELETE FROM sessions WHERE user_id=$1 AND expires_at <= now()",
        [user.id],
      );
      await client.query(
        "INSERT INTO sessions(token_hash,user_id,expires_at) VALUES($1,$2,$3)",
        [tokenHash(token), user.id, expiresAt],
      );
      const { password_hash: _, ...publicUser } = current;
      return { token, expiresAt, user: publicUser };
    });
  }

  async authenticate(token: string) {
    const result = await this.pool.query<User>(
      `SELECT u.id,u.email,u.name,u.role,u.active,u.farm_id AS "farmId",u.created_at AS "createdAt",u.avatar_data AS "avatarData"
      FROM sessions s JOIN users u ON u.id=s.user_id
      WHERE s.token_hash=$1 AND s.expires_at>now() AND u.active=true AND u.deleted_at IS NULL`,
      [tokenHash(token)],
    );
    if (!result.rows[0]) throw invalidSession();
    return result.rows[0];
  }

  async logout(token: string) {
    await this.pool.query("DELETE FROM sessions WHERE token_hash=$1", [
      tokenHash(token),
    ]);
  }

  async changePassword(
    userId: string,
    token: string,
    oldPassword: string,
    newPassword: string,
  ) {
    if (oldPassword === newPassword)
      throw new ApiError(
        400,
        "SAME_PASSWORD",
        "Mật khẩu mới phải khác mật khẩu hiện tại.",
      );
    const nextHash = await hashPassword(newPassword);
    await transaction(this.pool, async (client) => {
      const result = await client.query<PrivateUser>(
        "SELECT * FROM users WHERE id=$1 AND deleted_at IS NULL FOR UPDATE",
        [userId],
      );
      const user = result.rows[0];
      const session = await client.query(
        "SELECT 1 FROM sessions WHERE token_hash=$1 AND user_id=$2 AND expires_at>now()",
        [tokenHash(token), userId],
      );
      if (!user?.active || !session.rowCount) throw invalidSession();
      if (!(await verifyPassword(oldPassword, user.password_hash)))
        throw new ApiError(
          400,
          "WRONG_PASSWORD",
          "Mật khẩu hiện tại không đúng.",
        );
      await client.query("UPDATE users SET password_hash=$1 WHERE id=$2", [
        nextHash,
        userId,
      ]);
      await client.query("DELETE FROM sessions WHERE user_id=$1", [userId]);
    });
  }

  async createStaff(
    input: {
      name: string;
      email: string;
      password: string;
      role?: "STAFF" | "VET" | "ACCOUNTANT";
      code?: string;
    },
    farmId: string,
  ) {
    const passwordHash = await hashPassword(input.password);
    return transaction(this.pool, async (client) => {
      await client.query(
        "SELECT pg_advisory_xact_lock(hashtextextended($1,0))",
        [farmId],
      );
      const code =
        input.code ?? (await suggestCode(client, "users", "", farmId));
      const result = await client.query<User>(
        `INSERT INTO users(name,email,password_hash,role,farm_id,code) VALUES($1,$2,$3,$5,$4,$6) RETURNING ${publicColumns}`,
        [
          input.name,
          input.email,
          passwordHash,
          farmId,
          input.role ?? "STAFF",
          code,
        ],
      );
      return result.rows[0]!;
    });
  }

  async setStaffActive(id: string, active: boolean, farmId: string) {
    return transaction(this.pool, async (client) => {
      const found = await client.query<User>(
        `SELECT ${publicColumns} FROM users WHERE id=$1 AND farm_id=$2 AND deleted_at IS NULL FOR UPDATE`,
        [id, farmId],
      );
      const user = found.rows[0];
      if (!user)
        throw new ApiError(404, "USER_NOT_FOUND", "Không tìm thấy tài khoản.");
      // No API can demote or disable an administrator in this phase.
      if (user.role === "ADMIN")
        throw new ApiError(
          403,
          "ADMIN_PROTECTED",
          "Không được khóa tài khoản quản trị viên.",
        );
      const result = await client.query<User>(
        `UPDATE users SET active=$1 WHERE id=$2 RETURNING ${publicColumns}`,
        [active, id],
      );
      if (!active)
        await client.query("DELETE FROM sessions WHERE user_id=$1", [id]);
      return result.rows[0]!;
    });
  }

  async deleteStaff(id: string, farmId: string) {
    return transaction(this.pool, async (client) => {
      const found = await client.query<User>(
        `SELECT ${publicColumns} FROM users WHERE id=$1 AND farm_id=$2 AND deleted_at IS NULL FOR UPDATE`,
        [id, farmId],
      );
      const user = found.rows[0];
      if (!user)
        throw new ApiError(404, "USER_NOT_FOUND", "Không tìm thấy tài khoản.");
      if (user.role === "ADMIN")
        throw new ApiError(
          403,
          "ADMIN_PROTECTED",
          "Không được xóa tài khoản quản trị viên.",
        );
      await client.query("DELETE FROM sessions WHERE user_id=$1", [id]);
      // Preserve foreign-key audit history when an employee has performed work.
      // A savepoint allows only that expected FK failure to become a tombstone.
      await client.query("SAVEPOINT remove_staff");
      try {
        await client.query("DELETE FROM public.users WHERE id=$1", [id]);
      } catch (error) {
        if ((error as { code?: string }).code !== "23503") throw error;
        await client.query("ROLLBACK TO SAVEPOINT remove_staff");
        await client.query(
          "UPDATE public.users SET active=false,deleted_at=now(),email=$2,password_hash='deleted',avatar_data=NULL WHERE id=$1",
          [id, `deleted-${newToken().toLowerCase()}@smartfarm.invalid`],
        );
      }
      await client.query("RELEASE SAVEPOINT remove_staff");
    });
  }
}
