import { z } from "zod";

const configSchema = z.object({
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
  HOST: z.string().default("127.0.0.1"),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL: z
    .string()
    .url()
    .refine((value) => /^postgres(ql)?:/.test(value)),
  CORS_ORIGINS: z.string().default("http://localhost:8080"),
  SESSION_HOURS: z.coerce.number().int().min(1).max(168).default(8),
  WEATHER_API_KEY: z.string().trim().min(1).optional(),
});

export function readConfig() {
  const parsed = configSchema.safeParse(process.env);
  if (!parsed.success) {
    // Report field names only: configuration values can contain credentials.
    throw new Error(
      `Invalid environment fields: ${parsed.error.issues.map((i) => i.path.join(".")).join(", ")}`,
    );
  }
  return parsed.data;
}
export type Config = ReturnType<typeof readConfig>;
