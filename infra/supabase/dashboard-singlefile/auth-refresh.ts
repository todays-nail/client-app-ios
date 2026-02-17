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
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
function mintRefreshToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64Url(bytes);
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

async function signAccessJwt(user: { id: string; role?: string; kakao_user_id: string }) {
  return await create(
    { alg: "HS256", typ: "JWT" },
    {
      sub: user.id,
      kakao_user_id: user.kakao_user_id,
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
    const body = await readJson<{ refreshToken?: string; deviceId?: string }>(req);
    const refreshToken = body.refreshToken?.trim() ?? "";
    const deviceId = body.deviceId?.trim() ?? "";
    if (!refreshToken) return json(400, { message: "refreshToken is required" });
    if (!deviceId) return json(400, { message: "deviceId is required" });

    const pepper = requireEnv("REFRESH_TOKEN_PEPPER");
    const tokenHash = await sha256Hex(`${refreshToken}.${pepper}`);

    const { data: row, error: rowErr } = await supabase
      .from("user_refresh_tokens")
      .select("id, user_id, expires_at, revoked_at")
      .eq("token_hash", tokenHash)
      .eq("device_id", deviceId)
      .maybeSingle();

    if (rowErr) return json(500, { message: `refresh lookup failed: ${rowErr.message}` });
    if (!row) return json(401, { message: "invalid refresh token" });
    if (row.revoked_at) return json(401, { message: "refresh token revoked" });
    if (new Date(row.expires_at).getTime() <= Date.now()) return json(401, { message: "refresh token expired" });

    const { data: user, error: userErr } = await supabase
      .from("users")
      .select("id, role, kakao_user_id")
      .eq("id", row.user_id)
      .single();
    if (userErr) return json(500, { message: `user lookup failed: ${userErr.message}` });

    const newRefresh = mintRefreshToken();
    const newHash = await sha256Hex(`${newRefresh}.${pepper}`);
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

    const { data: inserted, error: insErr } = await supabase
      .from("user_refresh_tokens")
      .insert({ user_id: row.user_id, device_id: deviceId, token_hash: newHash, expires_at: expiresAt })
      .select("id")
      .single();
    if (insErr) return json(500, { message: `refresh insert failed: ${insErr.message}` });

    const { error: revErr } = await supabase
      .from("user_refresh_tokens")
      .update({ revoked_at: new Date().toISOString(), replaced_by: inserted.id })
      .eq("id", row.id);
    if (revErr) return json(500, { message: `refresh revoke failed: ${revErr.message}` });

    const accessToken = await signAccessJwt(user);
    return json(200, { accessToken, refreshToken: newRefresh });
  } catch (e) {
    return json(401, { message: e instanceof Error ? e.message : "Unknown error" });
  }
});

