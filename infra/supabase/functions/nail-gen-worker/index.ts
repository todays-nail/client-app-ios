import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { requireEnv } from "../_shared/env.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";
import {
  sendAIGenerationPushToTokens,
  type AIGenerationPushEventType,
  type APNSPushToken,
} from "../_shared/apns.ts";

const INPUT_BUCKET = "nail-inputs-private";
const RESULT_BUCKET = "nail-results-private";
const OPENAI_IMAGES_EDITS_URL = "https://api.openai.com/v1/images/edits";
const WORKER_SECRET = requireEnv("NAIL_GEN_WORKER_SECRET");
const OPENAI_API_KEY = requireEnv("OPENAI_API_KEY");
const MAX_BATCH = 3;
const MAX_OPENAI_ATTEMPTS = 2;
const IMAGE_MODEL: ImageModel = "gpt-image-1.5";
type ImageModel = "gpt-image-1.5";

class WorkerError extends Error {
  code: string;
  retriable: boolean;
  statusCode?: number;
  model?: ImageModel;

  constructor(code: string, message: string, retriable: boolean, statusCode?: number, model?: ImageModel) {
    super(message);
    this.name = "WorkerError";
    this.code = code;
    this.retriable = retriable;
    this.statusCode = statusCode;
    this.model = model;
  }
}

type JobRow = {
  id: string;
  user_id: string;
  shape: "almond" | "square" | "round";
  user_prompt: string;
  hand_object_path: string;
  reference_object_path: string;
  attempt_count: number;
  model: ImageModel;
};

type OpenAICallResult = {
  bytes: Uint8Array;
  model: ImageModel;
  downloadMs: number;
  openaiMs: number;
};

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function truncate(s: string, limit = 500): string {
  if (s.length <= limit) return s;
  return `${s.slice(0, limit)}...(truncated)`;
}

function contentTypeFromPath(path: string): string {
  const ext = path.split(".").pop()?.toLowerCase();
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

function decodeBase64(base64: string): Uint8Array {
  const binary = atob(base64);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

function encodeBase64(bytes: Uint8Array): string {
  const chunkSize = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}

function toDataUrl(bytes: Uint8Array, contentType: string): string {
  return `data:${contentType};base64,${encodeBase64(bytes)}`;
}

function normalizeError(e: unknown): { code: string; message: string } {
  if (e instanceof WorkerError) {
    return { code: e.code, message: truncate(e.message) };
  }
  if (e instanceof Error) {
    return { code: "INTERNAL_ERROR", message: truncate(e.message) };
  }
  return { code: "INTERNAL_ERROR", message: "Unknown error" };
}

function buildPrompt(shape: JobRow["shape"], userPrompt: string): string {
  const additionalRequest = userPrompt.trim();
  const shapeInstruction = (() => {
    switch (shape) {
      case "square":
        return "Shape enforcement (square): keep straight sidewalls and a flat free edge with crisp near-90-degree corners; avoid oval/almond taper.";
      case "round":
        return "Shape enforcement (round): keep gently curved sidewalls and a rounded free edge; avoid flat/boxy tips.";
      case "almond":
      default:
        return "Shape enforcement (almond): keep soft tapered sidewalls and a smooth rounded tip; avoid flat square tips.";
    }
  })();

  return [
    "You are a constrained nail-style transfer engine using TWO input images.",
    "Image 1 = immutable base hand photo. This image is the single source of truth for hand pose, finger shape, skin, nail geometry, jewelry, background, lighting, shadow, and camera perspective.",
    "Image 2 = design reference for nails only.",
    "",
    "Core goal (strict):",
    "Apply only the visible nail design style from Image 2 onto Image 1, and keep every non-nail pixel untouched.",
    "",
    "Do NOT alter background, finger shape, skin tone, lighting, shadows, jewelry, or scene composition.",
    "Do NOT perform color-graded style transfer across the whole hand/arm/body/backdrop.",
    "",
    "Nail transfer rules:",
    "- Detect design content only on visible nail areas.",
    "- Transfer color + motif layout + pattern geometry + brush/stroke density + finish from Image 2.",
    "- Keep per-nail variation and symmetry consistent with Image 1.",
    "- If design details from Image 2 are ambiguous on a finger, preserve the original nail there.",
    "- If user request is too specific to background/scene, ignore it and keep Image 1.",
    "",
    "Hard rules for Image 2 (ignore outside regions):",
    "- Background, hands, skin, tools, props, or decorations outside the nail shape in Image 2 must NEVER be copied.",
    "- Do NOT import logos, text, furniture, hands, rings, or backgrounds from Image 2.",
    "- Preserve each nail's own geometry and scale.",
    "- Preserve micro details: stroke thickness, edge sharpness, glitter/chrome/cat-eye cues, and texture direction.",
    "- Match design complexity level from Image 2; do not simplify detailed art into plain fills.",
    "- If decorations exist (stones/charms/decals), keep relative size and relative coordinates on each nail.",
    "",
    "Strict prohibitions:",
    "- Do not add extra fingers, extra nails, text, logo, watermark, or unrelated objects.",
    "- Do not paint broad background fills or global color overlays.",
    "- Never modify non-nail regions of Image 1.",
    "",
    `Target nail shape: ${shape}.`,
    shapeInstruction,
    additionalRequest.length > 0
      ? `User request (apply only to nails): ${additionalRequest}`
      : "User request (apply only to nails): none.",
    "",
    "Constraint precedence (apply in order):",
    "1) Keep non-nail areas unchanged.",
    "2) Preserve Image 1 hand realism.",
    "3) Transfer the nail style from Image 2.",
    "4) Apply user request only within nail regions, and ignore any part about background/scene/lighting/pose.",
  ].join("\n");
}

function jobLog(jobId: string, message: string): void {
  console.log(`[TODAYSNAIL][${jobId}][WORKER] ${message}`);
}

function clampMs(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.round(value));
}

async function downloadObject(path: string): Promise<Uint8Array> {
  const { data, error } = await supabaseAdmin.storage.from(INPUT_BUCKET).download(path);
  if (error || !data) {
    throw new WorkerError("INPUT_DOWNLOAD_FAILED", `download failed: ${error?.message ?? "not found"}`, false);
  }
  return new Uint8Array(await data.arrayBuffer());
}

async function callOpenAI(job: JobRow, model: ImageModel): Promise<OpenAICallResult> {
  const downloadStartedAt = performance.now();
  const [handBytes, referenceBytes] = await Promise.all([
    downloadObject(job.hand_object_path),
    downloadObject(job.reference_object_path),
  ]);
  const downloadMs = performance.now() - downloadStartedAt;

  const openaiStartedAt = performance.now();
  const payload = {
    model,
    prompt: buildPrompt(job.shape, job.user_prompt),
    images: [
      {
        image_url: toDataUrl(handBytes, contentTypeFromPath(job.hand_object_path)),
      },
      {
        image_url: toDataUrl(referenceBytes, contentTypeFromPath(job.reference_object_path)),
      },
    ],
    size: "auto",
    quality: "high",
    output_format: "png",
  };

  let response: Response;
  try {
    response = await fetch(OPENAI_IMAGES_EDITS_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "network error";
    throw new WorkerError("OPENAI_NETWORK", message, true);
  }

  if (!response.ok) {
    const raw = truncate(await response.text());
    const retriable = response.status === 429 || response.status >= 500;
    const code = response.status === 429
      ? "OPENAI_RATE_LIMIT"
      : response.status >= 500
      ? "OPENAI_SERVER"
      : "OPENAI_HTTP_ERROR";
    throw new WorkerError(code, `openai status=${response.status} body=${raw}`, retriable, response.status, model);
  }

  const json = await response.json() as {
    data?: Array<{
      result?: string;
      b64_json?: string;
      url?: string;
    }>;
  };
  const imageOutput = json.data?.[0];
  const b64 = imageOutput?.result ?? imageOutput?.b64_json;
  if (!b64) {
    if (imageOutput?.url) {
      let downloadResponse: Response;
      try {
        downloadResponse = await fetch(imageOutput.url);
      } catch (e) {
        const message = e instanceof Error ? e.message : "image download error";
        throw new WorkerError("OPENAI_BAD_RESPONSE", `image_url download failed: ${message}`, true, undefined, model);
      }
      if (!downloadResponse.ok) {
        throw new WorkerError(
          "OPENAI_BAD_RESPONSE",
          `image_url download failed status=${downloadResponse.status}`,
          true,
          downloadResponse.status,
          model,
        );
      }
      const openaiMs = performance.now() - openaiStartedAt;
      return {
        bytes: new Uint8Array(await downloadResponse.arrayBuffer()),
        model,
        downloadMs,
        openaiMs,
      };
    }

    throw new WorkerError(
      "OPENAI_BAD_RESPONSE",
      "missing image data in images/edits response",
      false,
    );
  }

  const openaiMs = performance.now() - openaiStartedAt;
  return {
    bytes: decodeBase64(b64),
    model,
    downloadMs,
    openaiMs,
  };
}

async function callOpenAIWithRetry(job: JobRow): Promise<OpenAICallResult> {
  let lastError: unknown = null;
  let lastTriedModel: ImageModel | undefined;

  for (let attempt = 1; attempt <= MAX_OPENAI_ATTEMPTS; attempt++) {
    lastTriedModel = IMAGE_MODEL;
    try {
      return await callOpenAI(job, IMAGE_MODEL);
    } catch (e) {
      lastError = e;
      if (!(e instanceof WorkerError)) {
        throw e;
      }

      if (e.retriable && attempt < MAX_OPENAI_ATTEMPTS) {
        const backoffMs = 800 * attempt;
        jobLog(
          job.id,
          `openai_retry image_api=edits image_model=${IMAGE_MODEL} attempt=${attempt} backoff_ms=${backoffMs}`,
        );
        await sleep(backoffMs);
        continue;
      }

      throw e;
    }
  }

  if (lastError) {
    if (lastError instanceof WorkerError && lastTriedModel && !lastError.model) {
      lastError.model = lastTriedModel;
    }
    throw lastError;
  }
  throw new WorkerError("OPENAI_UNKNOWN", "unexpected retry termination", false);
}

async function claimJob(job: JobRow): Promise<JobRow | null> {
  const { data, error } = await supabaseAdmin
    .from("nail_generation_jobs")
    .update({
      status: "processing",
      started_at: new Date().toISOString(),
      attempt_count: job.attempt_count + 1,
      error_code: null,
      error_message: null,
    })
    .eq("id", job.id)
    .eq("status", "queued")
    .eq("attempt_count", job.attempt_count)
    .select("id, user_id, shape, user_prompt, hand_object_path, reference_object_path, attempt_count, model")
    .maybeSingle();

  if (error) {
    throw new WorkerError("JOB_CLAIM_FAILED", error.message, false);
  }

  return (data as JobRow | null) ?? null;
}

async function completeJob(job: JobRow, resultObjectPath: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from("nail_generation_jobs")
    .update({
      status: "completed",
      result_object_path: resultObjectPath,
      model: job.model,
      completed_at: new Date().toISOString(),
      error_code: null,
      error_message: null,
    })
    .eq("id", job.id);

  if (error) {
    throw new WorkerError("JOB_COMPLETE_UPDATE_FAILED", error.message, false);
  }
}

async function failJob(jobId: string, code: string, message: string, model?: ImageModel): Promise<void> {
  await supabaseAdmin
    .from("nail_generation_jobs")
    .update({
      status: "failed",
      ...(model ? { model } : {}),
      error_code: code,
      error_message: truncate(message),
      completed_at: new Date().toISOString(),
    })
    .eq("id", jobId);
}

async function fetchActivePushTokens(userId: string): Promise<APNSPushToken[]> {
  const { data, error } = await supabaseAdmin
    .from("user_push_tokens")
    .select("id, apns_token, apns_env_hint")
    .eq("user_id", userId)
    .eq("platform", "ios")
    .eq("is_active", true);

  if (error) {
    throw new Error(`push token lookup failed: ${error.message}`);
  }

  return (data ?? []) as APNSPushToken[];
}

async function deactivateInvalidPushTokens(tokenIds: string[]): Promise<void> {
  if (tokenIds.length === 0) return;

  const { error } = await supabaseAdmin
    .from("user_push_tokens")
    .update({
      is_active: false,
      updated_at: new Date().toISOString(),
    })
    .in("id", tokenIds);

  if (error) {
    throw new Error(`push token deactivate failed: ${error.message}`);
  }
}

async function sendAIGenerationPush(job: JobRow, eventType: AIGenerationPushEventType): Promise<void> {
  try {
    const tokens = await fetchActivePushTokens(job.user_id);
    if (tokens.length === 0) {
      return;
    }

    const result = await sendAIGenerationPushToTokens({
      tokens,
      eventType,
      jobId: job.id,
    });

    if (result.invalidTokenIds.length > 0) {
      await deactivateInvalidPushTokens(result.invalidTokenIds);
    }

    const skipped = result.skippedReason ? ` skipped_reason=${result.skippedReason}` : "";
    jobLog(
      job.id,
      `push_dispatch event=${eventType} attempted=${result.attempted} sent=${result.sent} failed=${result.failed} invalidated=${result.invalidTokenIds.length}${skipped}`,
    );
  } catch (e) {
    const message = e instanceof Error ? truncate(e.message, 200) : "unknown";
    jobLog(job.id, `push_dispatch_failed event=${eventType} message=${message}`);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  const workerSecret = req.headers.get("x-worker-secret") ?? "";
  if (workerSecret !== WORKER_SECRET) {
    return errorResponse(401, "unauthorized worker call");
  }

  const { data: queuedJobs, error: queueError } = await supabaseAdmin
    .from("nail_generation_jobs")
    .select("id, user_id, shape, user_prompt, hand_object_path, reference_object_path, attempt_count, model")
    .eq("status", "queued")
    .order("created_at", { ascending: true })
    .limit(MAX_BATCH);

  if (queueError) {
    return errorResponse(500, `queued jobs lookup failed: ${queueError.message}`);
  }

  let claimedCount = 0;
  let completedCount = 0;
  let failedCount = 0;
  let skippedCount = 0;

  for (const rawJob of queuedJobs ?? []) {
    const job = rawJob as JobRow;
    let claimed: JobRow | null = null;
    try {
      claimed = await claimJob(job);
      if (!claimed) {
        skippedCount += 1;
        continue;
      }

      claimedCount += 1;
      const jobStartedAt = performance.now();
      const openaiResult = await callOpenAIWithRetry(claimed);
      const resultObjectPath = `${claimed.user_id}/${claimed.id}/result.png`;
      claimed.model = openaiResult.model;

      const uploadStartedAt = performance.now();
      const { error: uploadError } = await supabaseAdmin.storage
        .from(RESULT_BUCKET)
        .upload(resultObjectPath, openaiResult.bytes, {
          contentType: "image/png",
          upsert: true,
        });

      if (uploadError) {
        throw new WorkerError("RESULT_UPLOAD_FAILED", uploadError.message, false);
      }

      await completeJob(claimed, resultObjectPath);
      await sendAIGenerationPush(claimed, "ai_generation_completed");
      const uploadMs = performance.now() - uploadStartedAt;
      const totalMs = performance.now() - jobStartedAt;
      jobLog(
        claimed.id,
        `image_api=edits image_model=${openaiResult.model} download_ms=${clampMs(openaiResult.downloadMs)} openai_ms=${clampMs(openaiResult.openaiMs)} upload_ms=${clampMs(uploadMs)} total_ms=${clampMs(totalMs)}`,
      );
      completedCount += 1;
    } catch (e) {
      const normalized = normalizeError(e);
      const jobId = claimed?.id ?? job.id;
      const failedModel = e instanceof WorkerError ? e.model : undefined;
      await failJob(jobId, normalized.code, normalized.message, failedModel);
      if (claimed) {
        await sendAIGenerationPush(claimed, "ai_generation_failed");
      }
      jobLog(jobId, `failed code=${normalized.code} message=${truncate(normalized.message, 200)}`);
      failedCount += 1;
    }
  }

  return jsonResponse(200, {
    claimed: claimedCount,
    completed: completedCount,
    failed: failedCount,
    skipped: skippedCount,
  });
});
