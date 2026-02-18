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

type NailGenDeleteBody = {
  job_id?: string;
};

type NailGenerationRow = {
  id: string;
  user_id: string;
  parent_job_id: string | null;
  hand_object_path: string;
  reference_object_path: string;
  result_object_path: string | null;
};

const INPUT_BUCKET = "nail-inputs-private";
const RESULT_BUCKET = "nail-results-private";

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function parseUuid(value: string | undefined, name: string): string {
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

async function removeStorageObjects(bucket: string, objectPaths: string[]): Promise<void> {
  const filtered = objectPaths
    .map((path) => path.trim())
    .filter((path) => path.length > 0);
  if (filtered.length === 0) return;

  const { error } = await supabaseAdmin.storage
    .from(bucket)
    .remove(filtered);
  if (error) {
    throw new Error(`${bucket} cleanup failed: ${error.message}`);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  try {
    const userId = await requireUserId(req);
    const body = await readJson<NailGenDeleteBody>(req);
    const jobId = parseUuid(body.job_id, "job_id");

    const { data: targetJob, error: targetError } = await supabaseAdmin
      .from("nail_generation_jobs")
      .select("id, user_id, parent_job_id, hand_object_path, reference_object_path, result_object_path")
      .eq("id", jobId)
      .eq("user_id", userId)
      .maybeSingle();
    if (targetError) return errorResponse(500, `job lookup failed: ${targetError.message}`);
    if (!targetJob) return errorResponse(404, "job not found");

    const target = targetJob as NailGenerationRow;

    let jobsToDelete: NailGenerationRow[] = [target];
    if (!target.parent_job_id) {
      const { data: relatedRows, error: relatedError } = await supabaseAdmin
        .from("nail_generation_jobs")
        .select("id, user_id, parent_job_id, hand_object_path, reference_object_path, result_object_path")
        .eq("user_id", userId)
        .or(`id.eq.${target.id},parent_job_id.eq.${target.id}`);
      if (relatedError) return errorResponse(500, `related job lookup failed: ${relatedError.message}`);
      jobsToDelete = ((relatedRows ?? []) as NailGenerationRow[]);
    }

    const dedupedMap = new Map<string, NailGenerationRow>();
    for (const row of jobsToDelete) {
      dedupedMap.set(row.id, row);
    }
    const dedupedRows = Array.from(dedupedMap.values());
    const deleteJobIds = dedupedRows.map((row) => row.id.toLowerCase());

    await removeStorageObjects(
      INPUT_BUCKET,
      dedupedRows.flatMap((row) => [row.hand_object_path, row.reference_object_path]),
    );
    await removeStorageObjects(
      RESULT_BUCKET,
      dedupedRows.map((row) => row.result_object_path ?? ""),
    );

    const { error: deleteError } = await supabaseAdmin
      .from("nail_generation_jobs")
      .delete()
      .eq("user_id", userId)
      .in("id", deleteJobIds);
    if (deleteError) return errorResponse(500, `job delete failed: ${deleteError.message}`);

    return jsonResponse(200, {
      ok: true,
      deleted_job_ids: deleteJobIds,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    if (message.includes("job_id")) {
      return errorResponse(400, message);
    }
    if (message.includes("cleanup failed")) {
      return errorResponse(500, message);
    }
    return errorResponse(401, message);
  }
});
