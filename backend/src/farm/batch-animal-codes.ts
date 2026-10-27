import { ApiError } from "../auth/service.js";

/** Keep numbering within the same limit used by code suggestions. */
export function batchAnimalCodes(
  firstCode: string,
  quantity: number,
): string[] {
  const match = /^(.*?)([0-9]+)$/.exec(firstCode);
  if (!match || match[2]!.length > 12) {
    throw new ApiError(
      400,
      "INVALID_CODE",
      "Mã đầu tiên cần kết thúc bằng tối đa 12 chữ số, ví dụ GA-001.",
    );
  }
  const first = Number(match[2]);
  const last = first + quantity - 1;
  if (last > 999999999999) {
    throw new ApiError(
      400,
      "INVALID_CODE",
      "Dãy mã vượt quá 12 chữ số. Hãy chọn mã đầu tiên khác.",
    );
  }
  const codes = Array.from(
    { length: quantity },
    (_, i) => match[1]! + String(first + i).padStart(match[2]!.length, "0"),
  );
  if (codes.at(-1)!.length > 100) {
    throw new ApiError(
      400,
      "INVALID_CODE",
      "Mã cuối vượt quá 100 ký tự. Hãy rút ngắn mã đầu tiên.",
    );
  }
  return codes;
}
