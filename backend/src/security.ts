import {
  randomBytes,
  scrypt as scryptCallback,
  timingSafeEqual,
  createHash,
  type ScryptOptions,
} from "node:crypto";

function scrypt(
  password: string,
  salt: string,
  length: number,
  options: ScryptOptions,
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    scryptCallback(password, salt, length, options, (error, key) => {
      if (error) reject(error);
      else resolve(key);
    });
  });
}
const passwordCost = { N: 32768, r: 8, p: 3, maxmem: 64 * 1024 * 1024 };
export async function hashPassword(password: string) {
  const salt = randomBytes(16).toString("hex");
  const derived = (await scrypt(password, salt, 64, passwordCost)) as Buffer;
  return `scrypt-v1:${salt}:${derived.toString("hex")}`;
}
export async function verifyPassword(password: string, encoded: string) {
  const [algorithm, salt, hash] = encoded.split(":");
  if (
    !["scrypt", "scrypt-v1"].includes(algorithm ?? "") ||
    !salt ||
    !hash ||
    !/^[a-f0-9]{128}$/.test(hash)
  )
    return false;
  const derived = (await scrypt(
    password,
    salt,
    64,
    algorithm === "scrypt-v1" ? passwordCost : {},
  )) as Buffer;
  return timingSafeEqual(Buffer.from(hash, "hex"), derived);
}
export function newToken() {
  return randomBytes(32).toString("base64url");
}
export function tokenHash(token: string) {
  return createHash("sha256").update(token).digest("hex");
}
