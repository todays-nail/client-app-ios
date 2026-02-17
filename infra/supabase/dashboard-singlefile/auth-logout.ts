import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.95.3";

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
async function sha256Hex(text: string): Promise<string> {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

const supabase = createClient(
  requireEnv("SUPABASE_URL"),
  requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
  { auth: { persistSession: false, autoRefreshToken: false } },
);

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

    const { error } = await supabase
      .from("user_refresh_tokens")
      .update({ revoked_at: new Date().toISOString() })
      .eq("token_hash", tokenHash)
      .eq("device_id", deviceId)
      .is("revoked_at", null);

    if (error) return json(500, { message: `logout failed: ${error.message}` });
    return json(200, { ok: true });
  } catch (e) {
    return json(400, { message: e instanceof Error ? e.message : "Unknown error" });
  }
});

