import Fastify from "fastify";
import fastifyStatic from "@fastify/static";
import { access } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../../mobile/build/web/", import.meta.url));
await access(root + "index.html");
const app = Fastify({ logger: true });
await app.register(fastifyStatic, {
  root,
  index: "index.html",
  cacheControl: false,
});
await app.listen({ host: "127.0.0.1", port: 8080 });
process.on("SIGINT", () => {
  void app.close();
});
process.on("SIGTERM", () => {
  void app.close();
});
