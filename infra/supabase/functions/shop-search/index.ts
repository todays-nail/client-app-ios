import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import {
  errorResponse,
  getBearerToken,
  jsonResponse,
} from "../_shared/http.ts";
import { verifyAccessJwt } from "../_shared/jwt.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

type ShopRow = {
  id: string;
  name: string;
  address: string;
};

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function parseLimit(raw: string | null): number {
  if (!raw) return 20;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1 || n > 20) {
    throw new Error("limit must be integer between 1 and 20");
  }
  return n;
}

function parseQuery(raw: string | null): string {
  const value = raw?.trim() ?? "";
  if (value.length === 0) throw new Error("q is required");
  return value;
}

async function requireUserId(req: Request): Promise<string> {
  const token = getBearerToken(req);
  if (!token) throw new Error("missing bearer token");

  const payload = await verifyAccessJwt(token);
  const sub = payload["sub"];
  if (!sub || typeof sub !== "string" || !isUuid(sub)) {
    throw new Error("invalid token payload");
  }

  return sub.toLowerCase();
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET") return errorResponse(405, "Method not allowed");

  try {
    await requireUserId(req);

    const url = new URL(req.url);
    const query = parseQuery(url.searchParams.get("q"));
    const limit = parseLimit(url.searchParams.get("limit"));

    const { data, error } = await supabaseAdmin
      .from("shops")
      .select("id, name, address")
      .ilike("name", `%${query}%`)
      .order("name", { ascending: true })
      .limit(limit);

    if (error) return errorResponse(500, `shop search failed: ${error.message}`);

    const items = ((data ?? []) as ShopRow[]).map((shop) => ({
      id: shop.id,
      name: shop.name,
      address: shop.address,
    }));

    return jsonResponse(200, { items });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    if (message.includes("q") || message.includes("limit")) {
      return errorResponse(400, message);
    }
    return errorResponse(401, message);
  }
});
