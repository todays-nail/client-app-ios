import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.95.3";
import { verify } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
};

type RegionRow = {
  id: string;
  name: string;
  parent_id: string | null;
  level: number | null;
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

function getBearer(req: Request): string | null {
  const auth = req.headers.get("authorization") ?? req.headers.get("Authorization");
  if (!auth) return null;
  const m = auth.match(/^Bearer\s+(.+)$/i);
  return m?.[1] ?? null;
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function compareKoName(a: { name: string }, b: { name: string }): number {
  return a.name.localeCompare(b.name, "ko");
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
  if (!sub || typeof sub !== "string" || !isUuid(sub)) {
    throw new Error("invalid token payload");
  }

  return sub.toLowerCase();
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET") return json(405, { message: "Method not allowed" });

  try {
    await requireUserId(req);

    const { data, error } = await supabase
      .from("regions")
      .select("id, name, parent_id, level")
      .limit(5000);

    if (error) {
      return json(500, { message: `regions lookup failed: ${error.message}` });
    }

    const rows = (data ?? []) as RegionRow[];
    const districtsByParent = new Map<string, RegionRow[]>();

    for (const row of rows) {
      if (!row.parent_id) continue;
      const list = districtsByParent.get(row.parent_id) ?? [];
      list.push(row);
      districtsByParent.set(row.parent_id, list);
    }

    const cities = rows
      .filter((row) => row.parent_id === null)
      .sort(compareKoName)
      .map((city) => {
        const districts = (districtsByParent.get(city.id) ?? [])
          .sort(compareKoName)
          .map((district) => ({
            id: district.id,
            name: district.name,
            parent_id: district.parent_id,
            level: district.level,
          }));

        return {
          id: city.id,
          name: city.name,
          parent_id: city.parent_id,
          level: city.level,
          districts,
        };
      });

    return json(200, { cities });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    if (message.includes("missing bearer token") || message.includes("invalid token payload")) {
      return json(401, { message });
    }
    return json(500, { message });
  }
});
