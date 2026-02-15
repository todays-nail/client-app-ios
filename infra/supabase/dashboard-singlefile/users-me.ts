import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
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

  try {
    const userId = await requireUserId(req);

    if (req.method === "GET") {
      const { data: user, error } = await supabase
        .from("users")
        .select("id, role, nickname, phone, profile_image_url, created_at, updated_at")
        .eq("id", userId)
        .single();
      if (error) return json(500, { message: `users lookup failed: ${error.message}` });

      const nickname = (user.nickname ?? "").trim();
      return json(200, { user, needsOnboarding: nickname.length === 0 });
    }

    if (req.method === "PATCH") {
      const body = await readJson<{ nickname?: string; phone?: string | null; profile_image_url?: string | null }>(req);

      if (body.nickname !== undefined && body.nickname.trim().length === 0) {
        return json(400, { message: "nickname must be non-empty" });
      }

      const patch: Record<string, unknown> = {};
      if (body.nickname !== undefined) patch.nickname = body.nickname.trim();
      if (body.phone !== undefined) patch.phone = body.phone;
      if (body.profile_image_url !== undefined) patch.profile_image_url = body.profile_image_url;

      const { data: user, error } = await supabase
        .from("users")
        .update(patch)
        .eq("id", userId)
        .select("id, role, nickname, phone, profile_image_url, created_at, updated_at")
        .single();

      if (error) return json(500, { message: `users update failed: ${error.message}` });

      const nickname = (user.nickname ?? "").trim();
      return json(200, { user, needsOnboarding: nickname.length === 0 });
    }

    return json(405, { message: "Method not allowed" });
  } catch (e) {
    return json(401, { message: e instanceof Error ? e.message : "Unknown error" });
  }
});

