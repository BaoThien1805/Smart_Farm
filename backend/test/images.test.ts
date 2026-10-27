import { test } from "node:test";
import assert from "node:assert/strict";
import sharp from "sharp";
import { normalizeAnimalImage } from "../src/farm/images.js";
import { normalizePenIcon } from "../src/farm/pen-icons.js";

test("transparent animal PNG becomes a white JPEG instead of a black square", async () => {
  const png = await sharp({
    create: {
      width: 20,
      height: 20,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .png()
    .toBuffer();
  const data = await normalizeAnimalImage(png.toString("base64"));
  const { data: pixels, info } = await sharp(
    Buffer.from(data.split(",")[1]!, "base64"),
  )
    .raw()
    .toBuffer({ resolveWithObject: true });
  assert.equal(info.channels, 3);
  assert.ok([...pixels].every((value) => value >= 250));
});

test("pen icons keep transparency and aspect ratio while bounding dimensions", async () => {
  const input = await sharp({
    create: {
      width: 800,
      height: 400,
      channels: 4,
      background: { r: 40, g: 160, b: 100, alpha: 0.5 },
    },
  })
    .png()
    .toBuffer();
  const data = await normalizePenIcon(input.toString("base64"));
  assert.ok(data.startsWith("data:image/png;base64,"));
  const decoded = Buffer.from(data.split(",")[1]!, "base64");
  const metadata = await sharp(decoded).metadata();
  assert.equal(metadata.width, 256);
  assert.equal(metadata.height, 128);
  assert.equal(metadata.hasAlpha, true);
  const pixels = await sharp(decoded).ensureAlpha().raw().toBuffer();
  assert.ok(pixels[3]! >= 126 && pixels[3]! <= 129);
});

test("pen icons reject malformed, non-image and oversized input", async () => {
  for (const input of [
    "%%%%",
    Buffer.from("<svg/>").toString("base64"),
    Buffer.alloc(1024 * 1024 + 1).toString("base64"),
  ]) {
    await assert.rejects(normalizePenIcon(input), { statusCode: 400 });
  }
});
