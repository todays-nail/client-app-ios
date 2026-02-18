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

const INPUT_BUCKET = "nail-inputs-private";
const RESULT_BUCKET = "nail-results-private";
const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
const WORKER_SECRET = Deno.env.get("NAIL_GEN_WORKER_SECRET") ?? "";
const WORKER_TRIGGER_TIMEOUT_MS = 1500;

type NailShape = "almond" | "square" | "round";

type ReqBody = {
  source_job_id?: string;
  shape?: NailShape;
  user_prompt?: string;
};

type SourceJobRow = {
  id: string;
  user_id: string;
  status: string;
  result_object_path: string | null;
  reference_object_path: string;
  refinement_turn: number | null;
};

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function extensionFromPath(path: string, fallback: string): string {
  const ext = path.split(".").pop()?.trim().toLowerCase();
  if (!ext) return fallback;
  return ext;
}

function contentTypeFromPath(path: string): string {
  const ext = extensionFromPath(path, "png");
  switch (ext) {
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "webp":
      return "image/webp";
    case "png":
    default:
      return "image/png";
  }
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

async function copyReferenceObject(sourcePath: string, destinationPath: string): Promise<void> {
  const { error: copyError } = await supabaseAdmin.storage
    .from(INPUT_BUCKET)
    .copy(sourcePath, destinationPath);

  if (!copyError) return;

  // Fallback: download + upload when storage copy is not available.
  const { data: referenceData, error: downloadError } = await supabaseAdmin.storage
    .from(INPUT_BUCKET)
    .download(sourcePath);
  if (downloadError || !referenceData) {
    throw new Error(`source reference image not found: ${downloadError?.message ?? "not found"}`);
  }

  const bytes = new Uint8Array(await referenceData.arrayBuffer());
  const { error: uploadError } = await supabaseAdmin.storage
    .from(INPUT_BUCKET)
    .upload(destinationPath, bytes, {
      contentType: contentTypeFromPath(sourcePath),
      upsert: true,
    });

  if (uploadError) {
    throw new Error(`copy reference failed: ${uploadError.message}`);
  }
}

async function triggerWorkerNow(jobId: string): Promise<void> {
  if (!SUPABASE_URL || !WORKER_SECRET) {
    console.warn(`[nail-gen-refine-request] skip immediate worker trigger: missing env (job_id=${jobId})`);
    return;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), WORKER_TRIGGER_TIMEOUT_MS);

  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/nail-gen-worker`, {
      method: "POST",
      headers: {
        "x-worker-secret": WORKER_SECRET,
      },
      signal: controller.signal,
    });

    if (!response.ok) {
      const raw = await response.text();
      console.warn(
        `[nail-gen-refine-request] immediate worker trigger failed status=${response.status} job_id=${jobId} body=${raw.slice(0, 300)}`,
      );
    }
  } catch (e) {
    const message = e instanceof Error ? e.message : "unknown error";
    console.warn(`[nail-gen-refine-request] immediate worker trigger error job_id=${jobId} message=${message}`);
  } finally {
    clearTimeout(timeout);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  try {
    const userId = await requireUserId(req);
    const body = await readJson<ReqBody>(req);

    const sourceJobId = body.source_job_id?.trim().toLowerCase() ?? "";
    const shape = body.shape;
    const userPrompt = body.user_prompt?.trim() ?? "";

    if (!isUuid(sourceJobId)) {
      return errorResponse(400, "source_job_id must be uuid");
    }
    if (shape !== "almond" && shape !== "square" && shape !== "round") {
      return errorResponse(400, "shape must be one of: almond, square, round");
    }
    if (userPrompt.length < 1 || userPrompt.length > 500) {
      return errorResponse(400, "user_prompt length must be between 1 and 500");
    }

    const { data: sourceJob, error: sourceJobError } = await supabaseAdmin
      .from("nail_generation_jobs")
      .select("id, user_id, status, result_object_path, reference_object_path, refinement_turn")
      .eq("id", sourceJobId)
      .eq("user_id", userId)
      .maybeSingle();

    if (sourceJobError) return errorResponse(500, `source job lookup failed: ${sourceJobError.message}`);
    if (!sourceJob) return errorResponse(404, "job not found");

    const source = sourceJob as SourceJobRow;
    if (source.status !== "completed") {
      return errorResponse(409, "source job is not completed");
    }
    if ((source.refinement_turn ?? 0) !== 0) {
      return errorResponse(409, "refine already used");
    }

    const { data: existingChild, error: childLookupError } = await supabaseAdmin
      .from("nail_generation_jobs")
      .select("id")
      .eq("parent_job_id", sourceJobId)
      .limit(1)
      .maybeSingle();

    if (childLookupError) {
      return errorResponse(500, `child job lookup failed: ${childLookupError.message}`);
    }
    if (existingChild) {
      return errorResponse(409, "refine already used");
    }

    if (!source.result_object_path) {
      return errorResponse(500, "source result image not found");
    }

    const newJobId = crypto.randomUUID();
    const referenceExt = extensionFromPath(source.reference_object_path, "jpg");
    const newHandPath = `${userId}/${newJobId}/hand.png`;
    const newReferencePath = `${userId}/${newJobId}/reference_1.${referenceExt}`;

    const { data: resultData, error: resultDownloadError } = await supabaseAdmin.storage
      .from(RESULT_BUCKET)
      .download(source.result_object_path);
    if (resultDownloadError || !resultData) {
      return errorResponse(500, "source result image not found");
    }

    const resultBytes = new Uint8Array(await resultData.arrayBuffer());
    const { error: resultUploadError } = await supabaseAdmin.storage
      .from(INPUT_BUCKET)
      .upload(newHandPath, resultBytes, {
        contentType: contentTypeFromPath(source.result_object_path),
        upsert: true,
      });

    if (resultUploadError) {
      return errorResponse(500, `copy source result failed: ${resultUploadError.message}`);
    }

    try {
      await copyReferenceObject(source.reference_object_path, newReferencePath);
    } catch (e) {
      const message = e instanceof Error ? e.message : "copy reference failed";
      return errorResponse(500, message);
    }

    const { data: inserted, error: insertError } = await supabaseAdmin
      .from("nail_generation_jobs")
      .insert({
        id: newJobId,
        user_id: userId,
        status: "queued",
        shape,
        user_prompt: userPrompt,
        hand_object_path: newHandPath,
        reference_object_path: newReferencePath,
        model: "gpt-image-1.5",
        provider: "openai",
        parent_job_id: sourceJobId,
        refinement_turn: 1,
      })
      .select("id, status")
      .single();

    if (insertError) {
      if (insertError.code === "23505") {
        return errorResponse(409, "refine already used");
      }
      return errorResponse(500, `job insert failed: ${insertError.message}`);
    }

    await triggerWorkerNow(inserted.id);

    return jsonResponse(200, {
      job_id: inserted.id,
      status: inserted.status,
      poll_after_ms: 2000,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    return errorResponse(401, message);
  }
});
