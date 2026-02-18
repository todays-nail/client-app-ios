import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import {
  errorResponse,
  getBearerToken,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { verifyAccessJwt } from "../_shared/jwt.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

type QuoteRequestCreateBody = {
  job_id?: string;
  target_type?: string;
  region_id?: string | null;
  shop_id?: string | null;
};

type NailGenerationRow = {
  id: string;
  user_id: string;
  status: string;
};

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function parseUuid(value: string | undefined | null, name: string): string {
  const normalized = value?.trim().toLowerCase() ?? "";
  if (!isUuid(normalized)) {
    throw new Error(`${name} must be uuid`);
  }
  return normalized;
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
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  try {
    const userId = await requireUserId(req);
    const body = await readJson<QuoteRequestCreateBody>(req);

    const jobId = parseUuid(body.job_id, "job_id");
    const targetType = (body.target_type ?? "").trim().toUpperCase();
    if (targetType !== "REGION" && targetType !== "SHOP") {
      return errorResponse(400, "target_type must be REGION or SHOP");
    }

    const { data: jobRow, error: jobError } = await supabaseAdmin
      .from("nail_generation_jobs")
      .select("id, user_id, status")
      .eq("id", jobId)
      .eq("user_id", userId)
      .maybeSingle();
    if (jobError) return errorResponse(500, `job lookup failed: ${jobError.message}`);
    if (!jobRow) return errorResponse(404, "job not found");
    const job = jobRow as NailGenerationRow;
    if (job.status !== "completed") {
      return errorResponse(400, "job is not completed");
    }

    let regionId: string | null = null;
    let shopId: string | null = null;
    if (targetType === "REGION") {
      regionId = parseUuid(body.region_id, "region_id");
      const { data: region, error: regionError } = await supabaseAdmin
        .from("regions")
        .select("id")
        .eq("id", regionId)
        .maybeSingle();
      if (regionError) return errorResponse(500, `region lookup failed: ${regionError.message}`);
      if (!region) return errorResponse(404, "region not found");
    } else {
      shopId = parseUuid(body.shop_id, "shop_id");
      const { data: shop, error: shopError } = await supabaseAdmin
        .from("shops")
        .select("id")
        .eq("id", shopId)
        .maybeSingle();
      if (shopError) return errorResponse(500, `shop lookup failed: ${shopError.message}`);
      if (!shop) return errorResponse(404, "shop not found");
    }

    const { data: inserted, error: insertError } = await supabaseAdmin
      .from("quote_requests")
      .insert({
        user_id: userId,
        ai_generation_job_id: jobId,
        target_type: targetType,
        region_id: regionId,
        shop_id: shopId,
      })
      .select("id, user_id, ai_generation_job_id, target_type, region_id, shop_id, created_at, updated_at")
      .single();
    if (insertError) return errorResponse(500, `quote request insert failed: ${insertError.message}`);

    return jsonResponse(200, {
      ok: true,
      quote_request: inserted,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    if (message.includes("_id")) {
      return errorResponse(400, message);
    }
    return errorResponse(401, message);
  }
});
