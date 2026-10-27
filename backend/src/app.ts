import { codeSchema } from "./codes.js";
import { transaction } from "./database.js";
import { registerFinanceRoutes } from "./finance/routes.js";
import { registerReproductionRoutes } from "./reproduction/routes.js";
import { WeatherService } from "./weather.js";
import { WeatherRegionService } from "./weather-region.js";
import { normalizeAnimalImage as normalizeAvatarImage } from "./farm/images.js";
import { createFarmPool, withFarmScope } from "./database.js";
import { registerFarmRoutes } from "./farm/routes.js";
import { registerInventoryRoutes } from "./inventory/routes.js";
import Fastify, { type FastifyRequest } from "fastify";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import { z, ZodError } from "zod";
import type { Pool } from "pg";
import type { Config } from "./config.js";
import {
  ApiError,
  AuthService,
  emailSchema,
  passwordSchema,
  publicColumns,
  type User,
} from "./auth/service.js";

declare module "fastify" {
  interface FastifyRequest {
    account: User | null;
    sessionToken: string | null;
  }
}

export async function buildApp(
  pool: Pool,
  config: Config,
  logger = true,
  weatherRequest: typeof fetch = fetch,
) {
  const app = Fastify({
    logger: logger
      ? {
          redact: ["req.headers.authorization", "req.headers.cookie"],
          level: "info",
        }
      : false,
    bodyLimit: 16384,
  });
  await app.register(cors, {
    origin: config.CORS_ORIGINS.split(",").map((value) => value.trim()),
    methods: ["GET", "POST", "PATCH", "DELETE"],
    allowedHeaders: ["Authorization", "Content-Type"],
  });
  await app.register(helmet);
  await app.register(rateLimit, { max: 120, timeWindow: "1 minute" });
  app.decorateRequest("account", null);
  app.decorateRequest("sessionToken", null);
  app.addHook("onSend", async (_request, reply) => {
    reply.header("Cache-Control", "no-store");
  });
  const service = new AuthService(pool, config.SESSION_HOURS);

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof ZodError)
      return reply.code(400).send({
        error: {
          code: "VALIDATION_ERROR",
          message: "Vui lòng kiểm tra thông tin nhập.",
          fields: error.flatten().fieldErrors,
        },
      });
    if (error instanceof ApiError)
      return reply
        .code(error.statusCode)
        .send({ error: { code: error.code, message: error.message } });
    const failure = error as {
      code?: string;
      constraint?: string;
      statusCode?: number;
      name?: string;
    };
    if (failure.code === "23505")
      return reply.code(409).send({
        error: {
          code:
            failure.constraint === "users_email_key"
              ? "EMAIL_EXISTS"
              : "DUPLICATE_VALUE",
          message: "Email, mã hoặc tên này đã được sử dụng.",
        },
      });
    if (failure.code === "23503" || failure.code === "23514")
      return reply.code(409).send({
        error: {
          code: "DATA_CONFLICT",
          message: "Dữ liệu không hợp lệ hoặc đã được sử dụng trong lịch sử.",
        },
      });
    const status = failure.statusCode ?? 500;
    if (status >= 500)
      request.log.error(
        { code: failure.code, type: failure.name },
        "Request failed",
      );
    return reply.code(status).send({
      error: {
        code: status === 429 ? "RATE_LIMITED" : "REQUEST_FAILED",
        message:
          status === 429
            ? "Quá nhiều yêu cầu. Vui lòng thử lại sau."
            : status >= 500
              ? "Không thể xử lý lúc này. Vui lòng thử lại."
              : "Yêu cầu không hợp lệ.",
      },
    });
  });
  app.setNotFoundHandler((_request, reply) =>
    reply.code(404).send({
      error: { code: "NOT_FOUND", message: "Không tìm thấy đường dẫn." },
    }),
  );

  async function authenticate(request: FastifyRequest) {
    const match = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(
      request.headers.authorization ?? "",
    );
    if (!match?.[1])
      throw new ApiError(401, "UNAUTHENTICATED", "Vui lòng đăng nhập.");
    request.sessionToken = match[1];
    request.account = await service.authenticate(match[1]);
  }
  async function admin(request: FastifyRequest) {
    await authenticate(request);
    if (request.account!.role !== "ADMIN")
      throw new ApiError(
        403,
        "FORBIDDEN",
        "Bạn không có quyền thực hiện thao tác này.",
      );
  }
  function allow(roles: readonly User["role"][]) {
    return async (request: FastifyRequest) => {
      await authenticate(request);
      if (!roles.includes(request.account!.role))
        throw new ApiError(
          403,
          "FORBIDDEN",
          "Bạn không có quyền thực hiện thao tác này.",
        );
    };
  }
  const operate = allow(["ADMIN", "STAFF"]);
  const care = allow(["ADMIN", "STAFF", "VET"]);
  const examine = allow(["ADMIN", "VET"]);
  const finance = allow(["ADMIN", "ACCOUNTANT"]);
  const weather = new WeatherService(config.WEATHER_API_KEY, weatherRequest);
  const weatherRegion = new WeatherRegionService(weatherRequest);
  app.get(
    "/api/farm/location",
    { preHandler: authenticate },
    async (request) => {
      const result = await pool.query(
        "SELECT name, latitude, longitude FROM public.farms WHERE id=$1",
        [request.account!.farmId],
      );
      return { location: result.rows[0] };
    },
  );
  app.patch("/api/farm/location", { preHandler: admin }, async (request) => {
    const body = z
      .object({
        latitude: z.number().min(-90).max(90),
        longitude: z.number().min(-180).max(180),
      })
      .strict()
      .parse(request.body);
    const result = await pool.query(
      "UPDATE public.farms SET latitude=$1, longitude=$2 WHERE id=$3 RETURNING name,latitude,longitude",
      [body.latitude, body.longitude, request.account!.farmId],
    );
    return { location: result.rows[0] };
  });
  app.get("/api/weather", { preHandler: authenticate }, async (request) => {
    const result = await pool.query(
      "SELECT name,latitude,longitude FROM public.farms WHERE id=$1",
      [request.account!.farmId],
    );
    const location = result.rows[0];
    if (location?.latitude == null || location.longitude == null)
      throw new ApiError(
        409,
        "FARM_LOCATION_REQUIRED",
        "Chưa đặt vị trí trang trại.",
      );
    const [data, region] = await Promise.all([
      weather.current(location),
      weatherRegion.current(location),
    ]);
    return { ...data, region };
  });
  app.get("/api/health", async () => {
    await pool.query("SELECT 1");
    return { status: "ok" };
  });
  app.post(
    "/api/auth/login",
    { config: { rateLimit: { max: 10, timeWindow: "1 minute" } } },
    async (request) => {
      const body = z
        .object({ email: emailSchema, password: z.string().min(1).max(128) })
        .strict()
        .parse(request.body);
      return service.login(body.email, body.password);
    },
  );
  app.post(
    "/api/auth/register",
    { config: { rateLimit: { max: 5, timeWindow: "1 minute" } } },
    async (request, reply) => {
      const body = z
        .object({
          name: z.string().trim().min(2).max(100),
          farmName: z.string().trim().min(2).max(100),
          email: emailSchema,
          password: passwordSchema,
        })
        .strict()
        .parse(request.body);
      return reply.code(201).send(await service.register(body));
    },
  );
  app.get("/api/auth/me", { preHandler: authenticate }, async (request) => ({
    user: request.account,
  }));
  app.post(
    "/api/auth/logout",
    { preHandler: authenticate },
    async (request, reply) => {
      await service.logout(request.sessionToken!);
      return reply.code(204).send();
    },
  );
  app.post(
    "/api/auth/password",
    {
      preHandler: authenticate,
      config: { rateLimit: { max: 10, timeWindow: "1 minute" } },
    },
    async (request, reply) => {
      const body = z
        .object({
          currentPassword: z.string().min(1).max(128),
          newPassword: passwordSchema,
        })
        .strict()
        .parse(request.body);
      await service.changePassword(
        request.account!.id,
        request.sessionToken!,
        body.currentPassword,
        body.newPassword,
      );
      return reply.code(204).send();
    },
  );
  app.get("/api/users", { preHandler: admin }, async (request) => {
    const query = z
      .object({
        page: z.coerce.number().int().min(1).max(100000).default(1),
        pageSize: z.coerce.number().int().min(1).max(100).default(20),
      })
      .parse(request.query);
    const result = await pool.query<User & { total: string }>(
      `SELECT ${publicColumns}, count(*) OVER() AS total FROM users WHERE farm_id=$3 AND deleted_at IS NULL ORDER BY created_at DESC,id LIMIT $1 OFFSET $2`,
      [
        query.pageSize,
        (query.page - 1) * query.pageSize,
        request.account!.farmId,
      ],
    );
    // Count separately on out-of-range pages so pagination remains accurate.
    const total =
      result.rows[0]?.total ??
      (
        await pool.query<{ count: string }>(
          "SELECT count(*) FROM users WHERE farm_id=$1 AND deleted_at IS NULL",
          [request.account!.farmId],
        )
      ).rows[0]!.count;
    return {
      users: result.rows.map(({ total: _, ...user }) => user),
      total: Number(total),
      ...query,
    };
  });
  app.post("/api/users", { preHandler: admin }, async (request, reply) => {
    const body = z
      .object({
        code: codeSchema.optional(),
        name: z.string().trim().min(2).max(100),
        email: emailSchema,
        password: passwordSchema,
        role: z.enum(["STAFF", "VET", "ACCOUNTANT"]).default("STAFF"),
      })
      .strict()
      .parse(request.body);
    return reply
      .code(201)
      .send({ user: await service.createStaff(body, request.account!.farmId) });
  });
  app.patch(
    "/api/users/:id",
    { preHandler: admin, bodyLimit: 1500000 },
    async (request) => {
      const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
      const body = z
        .object({
          name: z.string().trim().min(2).max(100),
          email: emailSchema,
          code: codeSchema.optional(),
          role: z.enum(["ADMIN", "STAFF", "VET", "ACCOUNTANT"]),
          photoBase64: z.string().min(1).max(1398104).nullable().optional(),
        })
        .strict()
        .parse(request.body);
      return transaction(pool, async (client) => {
        const found = await client.query<User>(
          `SELECT ${publicColumns} FROM public.users WHERE id=$1 AND farm_id=$2 AND deleted_at IS NULL FOR UPDATE`,
          [id, request.account!.farmId],
        );
        const user = found.rows[0];
        if (!user)
          throw new ApiError(
            404,
            "USER_NOT_FOUND",
            "Không tìm thấy tài khoản.",
          );
        if ((user.role === "ADMIN") !== (body.role === "ADMIN"))
          throw new ApiError(
            403,
            "ADMIN_PROTECTED",
            "Không được thay đổi vai trò chủ trang trại.",
          );
        const avatar =
          body.photoBase64 === undefined
            ? user.avatarData
            : body.photoBase64 === null
              ? null
              : await normalizeAvatarImage(body.photoBase64);
        const result = await client.query<User>(
          `UPDATE public.users SET name=$1,email=$2,role=$3,code=$4,avatar_data=$5 WHERE id=$6 AND farm_id=$7 AND deleted_at IS NULL RETURNING ${publicColumns}`,
          [
            body.name,
            body.email,
            body.role,
            body.code ?? user.code,
            avatar,
            id,
            request.account!.farmId,
          ],
        );
        if (user.role !== body.role)
          await client.query("DELETE FROM public.sessions WHERE user_id=$1", [
            id,
          ]);
        return { user: result.rows[0]! };
      });
    },
  );
  app.patch(
    "/api/users/:id/avatar",
    { preHandler: admin, bodyLimit: 1500000 },
    async (request) => {
      const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
      const body = z
        .object({ photoBase64: z.string().min(1).max(1398104).nullable() })
        .strict()
        .parse(request.body);
      const target = await pool.query(
        "SELECT id FROM public.users WHERE id=$1 AND farm_id=$2 AND deleted_at IS NULL",
        [id, request.account!.farmId],
      );
      if (!target.rowCount)
        throw new ApiError(404, "USER_NOT_FOUND", "Không tìm thấy tài khoản.");
      const avatar =
        body.photoBase64 === null
          ? null
          : await normalizeAvatarImage(body.photoBase64);
      const result = await pool.query(
        `UPDATE public.users SET avatar_data=$1 WHERE id=$2 AND farm_id=$3 AND deleted_at IS NULL RETURNING ${publicColumns}`,
        [avatar, id, request.account!.farmId],
      );
      if (!result.rowCount)
        throw new ApiError(404, "USER_NOT_FOUND", "Không tìm thấy tài khoản.");
      return { user: result.rows[0] };
    },
  );
  app.patch("/api/users/:id/status", { preHandler: admin }, async (request) => {
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const { active } = z
      .object({ active: z.boolean() })
      .strict()
      .parse(request.body);
    return {
      user: await service.setStaffActive(id, active, request.account!.farmId),
    };
  });
  app.delete(
    "/api/users/:id",
    { preHandler: admin },
    async (request, reply) => {
      const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
      await service.deleteStaff(id, request.account!.farmId);
      return reply.code(204).send();
    },
  );
  // Scope only farm handlers, after their authentication preHandler has completed.
  app.addHook("onRoute", (route) => {
    const handler = route.handler;
    route.handler = async function (request, reply) {
      if (!request.account)
        throw new ApiError(401, "UNAUTHENTICATED", "Vui lòng đăng nhập.");
      const farm = await pool.query<{ schema_name: string }>(
        "SELECT schema_name FROM farms WHERE id=$1",
        [request.account.farmId],
      );
      if (!farm.rows[0])
        throw new ApiError(403, "FARM_NOT_FOUND", "Không tìm thấy trang trại.");
      return withFarmScope(farm.rows[0].schema_name, () =>
        handler.call(this, request, reply),
      );
    };
  });
  const farmPool = createFarmPool(pool);
  await registerFarmRoutes(app, farmPool, {
    authenticate,
    admin,
    operate,
    care,
    examine,
  });
  await registerInventoryRoutes(app, farmPool, {
    authenticate,
    admin,
    operate,
  });
  await registerFinanceRoutes(app, farmPool, { admin, finance });
  await registerReproductionRoutes(app, farmPool, {
    authenticate,
    operate,
    admin,
  });
  return app;
}
