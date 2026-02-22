import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.95.3";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
};

function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

async function readJson<T>(req: Request): Promise<T> {
  const text = await req.text();
  return text ? JSON.parse(text) : ({} as T);
}

function base64Url(bytes: Uint8Array): string {
  const b64 = btoa(String.fromCharCode(...bytes));
  return b64.replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

async function sha256Hex(text: string): Promise<string> {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function mintRefreshToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64Url(bytes);
}

type KakaoVerifyResult = {
  id: string;
  nickname: string | null;
  profileImageURL: string | null;
};

function normalizedOptionalString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

async function verifyKakaoAccessToken(token: string): Promise<KakaoVerifyResult> {
  const resp = await fetch("https://kapi.kakao.com/v2/user/me", {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
    },
  });
  if (!resp.ok) throw new Error(`Kakao verify failed: ${resp.status}`);
  const data = await resp.json() as {
    id?: string | number;
    kakao_account?: {
      profile?: {
        nickname?: string | null;
        profile_image_url?: string | null;
      };
    };
  };
  if (data.id === undefined || data.id === null) throw new Error("Kakao id missing");
  return {
    id: String(data.id),
    nickname: normalizedOptionalString(data.kakao_account?.profile?.nickname),
    profileImageURL: normalizedOptionalString(data.kakao_account?.profile?.profile_image_url),
  };
}

const supabase = createClient(
  requireEnv("SUPABASE_URL"),
  requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const jwtKey = await crypto.subtle.importKey(
  "raw",
  new TextEncoder().encode(requireEnv("APP_JWT_SECRET")),
  { name: "HMAC", hash: "SHA-256" },
  false,
  ["sign"],
);

async function signAccessJwt(user: { id: string; role?: string }) {
  return await create(
    { alg: "HS256", typ: "JWT" },
    {
      sub: user.id,
      role: user.role ?? "USER",
      iss: "todaysnail-edge",
      exp: getNumericDate(15 * 60),
    },
    jwtKey,
  );
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { message: "Method not allowed" });

  try {
    const body = await readJson<{ kakaoAccessToken?: string; deviceId?: string }>(req);
    const kakaoAccessToken = body.kakaoAccessToken?.trim() ?? "";
    const deviceId = body.deviceId?.trim() ?? "";
    if (!kakaoAccessToken) return json(400, { message: "kakaoAccessToken is required" });
    if (!deviceId) return json(400, { message: "deviceId is required" });

    const kakaoProfile = await verifyKakaoAccessToken(kakaoAccessToken);
    const kakaoUserId = kakaoProfile.id;

    const { data: existingUser, error: existingErr } = await supabase
      .from("users")
      .select("id, deleted_at")
      .eq("kakao_user_id", kakaoUserId)
      .maybeSingle();
    if (existingErr) return json(500, { message: `users lookup failed: ${existingErr.message}` });
    if (existingUser?.deleted_at) return json(403, { message: "account is deleted" });

    const { data: user, error: upsertErr } = await supabase
      .from("users")
      .upsert({ kakao_user_id: kakaoUserId, role: "USER" }, { onConflict: "kakao_user_id" })
      .select("id, role, nickname, phone, profile_image_url, created_at, updated_at, kakao_user_id")
      .single();

    if (upsertErr) return json(500, { message: `users upsert failed: ${upsertErr.message}` });

    const accessToken = await signAccessJwt(user);

    const refreshToken = mintRefreshToken();
    const pepper = requireEnv("REFRESH_TOKEN_PEPPER");
    const tokenHash = await sha256Hex(`${refreshToken}.${pepper}`);
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

    const { error: rtErr } = await supabase
      .from("user_refresh_tokens")
      .insert({
        user_id: user.id,
        device_id: deviceId,
        token_hash: tokenHash,
        expires_at: expiresAt,
      });

    if (rtErr) return json(500, { message: `refresh token insert failed: ${rtErr.message}` });

    const nickname = (user.nickname ?? "").trim();
    const needsOnboarding = nickname.length === 0;

    return json(200, {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        role: user.role,
        nickname: user.nickname,
        phone: user.phone,
        profile_image_url: user.profile_image_url,
        created_at: user.created_at,
        updated_at: user.updated_at,
      },
      needsOnboarding,
      onboarding_prefill: {
        nickname: kakaoProfile.nickname,
        profile_image_url: kakaoProfile.profileImageURL,
      },
    });
  } catch (e) {
    return json(401, { message: e instanceof Error ? e.message : "Unknown error" });
  }
});
