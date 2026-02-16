import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import {
  errorResponse,
  getBearerToken,
  jsonResponse,
} from "../_shared/http.ts";
import { verifyAccessJwt } from "../_shared/jwt.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";
import { requireEnv } from "../_shared/env.ts";

const RESULT_BUCKET = "nail-results-private";
const RESULT_URL_EXPIRES_SEC = 10 * 60;

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function absolutizeSignedUrl(signedUrl: string): string {
  if (signedUrl.startsWith("http://") || signedUrl.startsWith("https://")) {
    return signedUrl;
  }

  const supabaseUrl = requireEnv("SUPABASE_URL").replace(/\/+$/, "");
  if (signedUrl.startsWith("/storage/v1/")) return `${supabaseUrl}${signedUrl}`;
  if (signedUrl.startsWith("/object/")) return `${supabaseUrl}/storage/v1${signedUrl}`;
  if (signedUrl.startsWith("/")) return `${supabaseUrl}${signedUrl}`;
  return `${supabaseUrl}/${signedUrl}`;
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
    const userId = await requireUserId(req);
    const url = new URL(req.url);
    const jobId = url.searchParams.get("job_id")?.trim().toLowerCase() ?? "";
    if (!isUuid(jobId)) return errorResponse(400, "job_id must be uuid");

    const { data: job, error } = await supabaseAdmin
      .from("nail_generation_jobs")
      .select("id, user_id, status, result_object_path, error_code, error_message")
      .eq("id", jobId)
      .eq("user_id", userId)
      .maybeSingle();

    if (error) return errorResponse(500, `job lookup failed: ${error.message}`);
    if (!job) return errorResponse(404, "job not found");

    let resultImageUrl: string | null = null;
    if (job.status === "completed" && job.result_object_path) {
      const { data: signed, error: signedError } = await supabaseAdmin.storage
        .from(RESULT_BUCKET)
        .createSignedUrl(job.result_object_path, RESULT_URL_EXPIRES_SEC);

      if (signedError || !signed?.signedUrl) {
        return errorResponse(500, `createSignedUrl failed: ${signedError?.message ?? "unknown"}`);
      }
      resultImageUrl = absolutizeSignedUrl(signed.signedUrl);
    }

    return jsonResponse(200, {
      status: job.status,
      result_image_url: resultImageUrl,
      error_code: job.error_code,
      error_message: job.error_message,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    return errorResponse(401, message);
  }
});
