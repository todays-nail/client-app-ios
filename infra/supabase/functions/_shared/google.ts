import { createRemoteJWKSet, jwtVerify } from "https://esm.sh/jose@5.9.6";
import { requireEnv } from "./env.ts";

export type GoogleProfile = {
  sub: string;
  email: string | null;
  emailVerified: boolean;
  name: string | null;
  picture: string | null;
};

const googleJWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs"),
);

const allowedAudiences = requireEnv("GOOGLE_OAUTH_AUDIENCES")
  .split(",")
  .map((v) => v.trim())
  .filter((v) => v.length > 0);

if (allowedAudiences.length === 0) {
  throw new Error("Missing required env value: GOOGLE_OAUTH_AUDIENCES");
}

function normalizedOptionalString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeEmailVerified(value: unknown): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") return value.toLowerCase() == "true";
  return false;
}

export async function verifyGoogleIdToken(idToken: string): Promise<GoogleProfile> {
  const token = idToken.trim();
  if (!token) {
    throw new Error("Google verify failed: missing id token");
  }

  const { payload } = await jwtVerify(token, googleJWKS, {
    issuer: ["accounts.google.com", "https://accounts.google.com"],
    audience: allowedAudiences,
  });

  const sub = payload.sub?.trim();
  if (!sub) {
    throw new Error("Google verify failed: missing sub");
  }

  return {
    sub,
    email: normalizedOptionalString(payload.email),
    emailVerified: normalizeEmailVerified(payload.email_verified),
    name: normalizedOptionalString(payload.name),
    picture: normalizedOptionalString(payload.picture),
  };
}
