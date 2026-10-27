import sharp from "sharp";
import { ApiError } from "../auth/service.js";
export async function normalizeAnimalImage(base64: string): Promise<string> {
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(base64) || base64.length % 4 !== 0)
    throw new ApiError(400, "INVALID_IMAGE", "Ảnh không hợp lệ.");
  const bytes = Buffer.from(base64, "base64");
  if (bytes.length > 1024 * 1024)
    throw new ApiError(400, "IMAGE_TOO_LARGE", "Ảnh tối đa 1 MB.");
  const png = bytes
    .subarray(0, 8)
    .equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  const jpg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  if (!png && !jpg)
    throw new ApiError(400, "INVALID_IMAGE", "Chỉ nhận ảnh JPEG hoặc PNG.");
  try {
    const output = await sharp(bytes, {
      limitInputPixels: 20000000,
      failOn: "warning",
    })
      .rotate()
      .resize(400, 400, { fit: "cover", withoutEnlargement: true })
      .flatten({ background: "#ffffff" })
      .jpeg({ quality: 75 })
      .toBuffer();
    return `data:image/jpeg;base64,${output.toString("base64")}`;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(
      400,
      "INVALID_IMAGE",
      "Không đọc được ảnh. Hãy chọn ảnh JPEG/PNG khác.",
    );
  }
}
