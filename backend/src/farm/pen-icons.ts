import sharp from "sharp";
import { ApiError } from "../auth/service.js";

export const penIconKeys = [
  "auto",
  "barn",
  "cow",
  "pig",
  "goat",
  "chicken",
  "buffalo",
  "sheep",
  "duck",
  "muscovy",
  "goose",
  "fish",
  "shrimp",
  "rabbit",
  "custom",
] as const;
export const penIconsMigration = `
ALTER TABLE pens ADD COLUMN icon_key text NOT NULL DEFAULT 'auto' CHECK(icon_key IN ('auto','barn','cow','pig','goat','chicken','buffalo','sheep','duck','muscovy','goose','fish','shrimp','rabbit','custom'));
ALTER TABLE pens ADD COLUMN icon_data text CHECK(icon_data IS NULL OR (icon_data LIKE 'data:image/png;base64,%' AND length(icon_data)<=1398104));
ALTER TABLE pens ADD CONSTRAINT pens_icon_consistency CHECK((icon_key='custom')=(icon_data IS NOT NULL));`;

export async function normalizePenIcon(base64: string): Promise<string> {
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(base64) || base64.length % 4 !== 0)
    throw new ApiError(400, "INVALID_IMAGE", "Icon không hợp lệ.");
  const bytes = Buffer.from(base64, "base64");
  if (bytes.length > 1024 * 1024)
    throw new ApiError(400, "IMAGE_TOO_LARGE", "Icon tối đa 1 MB sau xử lý.");
  const png = bytes
    .subarray(0, 8)
    .equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  const jpg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  if (!png && !jpg)
    throw new ApiError(400, "INVALID_IMAGE", "Chỉ nhận icon JPEG hoặc PNG.");
  try {
    const output = await sharp(bytes, {
      limitInputPixels: 20000000,
      failOn: "warning",
    })
      .rotate()
      .resize(256, 256, { fit: "inside", withoutEnlargement: true })
      .png({ compressionLevel: 9 })
      .toBuffer();
    return `data:image/png;base64,${output.toString("base64")}`;
  } catch {
    throw new ApiError(
      400,
      "INVALID_IMAGE",
      "Không đọc được icon. Hãy chọn ảnh JPEG/PNG khác.",
    );
  }
}
