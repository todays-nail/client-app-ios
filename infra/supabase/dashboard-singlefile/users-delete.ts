import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.95.3";
import { verify } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

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
function getBearer(req: Request): string | null {
  const h = req.headers.get("authorization") ?? req.headers.get("Authorization");
  if (!h) return null;
  const m = h.match(/^Bearer\\s+(.+)$/i);
  return m?.[1] ?? null;
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
  ["verify"],
);

async function requireUserId(req: Request): Promise<string> {
  const token = getBearer(req);
  if (!token) throw new Error("missing bearer token");
  const payload = await verify(token, jwtKey, "HS256") as Record<string, unknown>;
  const sub = payload["sub"];
  if (!sub || typeof sub !== "string") throw new Error("invalid token payload");
  return sub;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { message: "Method not allowed" });

  try {
    const userId = await requireUserId(req);
    const body = await readJson<{ reason?: string | null }>(req);
    const now = new Date().toISOString();

    const reason = typeof body.reason === "string"
      ? body.reason.trim() || null
      : null;

    const { data: user, error: userErr } = await supabase
      .from("users")
      .select("id, deleted_at")
      .eq("id", userId)
      .maybeSingle();
    if (userErr) return json(500, { message: `users lookup failed: ${userErr.message}` });
    if (!user) return json(404, { message: "user not found" });

    if (!user.deleted_at) {
      const { error: deleteErr } = await supabase
        .from("users")
        .update({
          deleted_at: now,
          deleted_reason: reason,
        })
        .eq("id", userId);
      if (deleteErr) return json(500, { message: `users delete failed: ${deleteErr.message}` });
    }

    const { error: revokeErr } = await supabase
      .from("user_refresh_tokens")
      .update({ revoked_at: now })
      .eq("user_id", userId)
      .is("revoked_at", null);
    if (revokeErr) return json(500, { message: `refresh token revoke failed: ${revokeErr.message}` });

    return json(200, { ok: true });
  } catch (e) {
    return json(401, { message: e instanceof Error ? e.message : "Unknown error" });
  }
});
