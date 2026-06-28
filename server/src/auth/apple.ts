import { createRemoteJWKSet, jwtVerify } from "jose";

// Apple 的公钥集（jose 自动缓存/轮换）。
const APPLE_JWKS = createRemoteJWKSet(
  new URL("https://appleid.apple.com/auth/keys")
);

export type AppleIdentity = {
  sub: string; // Apple 用户唯一 id
  email?: string;
};

// 验 Sign in with Apple 的 identityToken：
// 校验签名（Apple JWKS）+ issuer + audience(=bundle id)。
export async function verifyAppleIdentityToken(
  identityToken: string,
  bundleId: string
): Promise<AppleIdentity> {
  const { payload } = await jwtVerify(identityToken, APPLE_JWKS, {
    issuer: "https://appleid.apple.com",
    audience: bundleId,
  });
  if (!payload.sub) throw new Error("apple token missing sub");
  return { sub: String(payload.sub), email: payload.email as string | undefined };
}
