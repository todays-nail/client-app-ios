import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { requireEnv } from "../_shared/env.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

const INPUT_BUCKET = "nail-inputs-private";
const RESULT_BUCKET = "nail-results-private";
const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const WORKER_SECRET = requireEnv("NAIL_GEN_WORKER_SECRET");
const OPENAI_API_KEY = requireEnv("OPENAI_API_KEY");
const MAX_BATCH = 3;

class WorkerError extends Error {
  code: string;
  retriable: boolean;

  constructor(code: string, message: string, retriable: boolean) {
    super(message);
    this.name = "WorkerError";
    this.code = code;
    this.retriable = retriable;
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
  return [
    "Apply the nail design style from the reference image to the hand photo.",
    `Target nail shape: ${shape}.`,
    `Additional request: ${userPrompt}`,
    "Keep hand pose, skin, fingers, jewelry, and background unchanged.",
    "Edit only fingernails and nail art.",
    "Maintain realistic shadows and lighting.",
    "Do not add extra fingers, hands, text, or watermark.",
  ].join("\n");
}

async function downloadObject(path: string): Promise<Uint8Array> {
  const { data, error } = await supabaseAdmin.storage.from(INPUT_BUCKET).download(path);
  if (error || !data) {
    throw new WorkerError("INPUT_DOWNLOAD_FAILED", `download failed: ${error?.message ?? "not found"}`, false);
  }
  return new Uint8Array(await data.arrayBuffer());
}

async function callOpenAI(job: JobRow): Promise<Uint8Array> {
  const [handBytes, referenceBytes] = await Promise.all([
    downloadObject(job.hand_object_path),
    downloadObject(job.reference_object_path),
  ]);

  const payload = {
    model: "gpt-4.1-mini",
    input: [
      {
        role: "user",
        content: [
          { type: "input_text", text: buildPrompt(job.shape, job.user_prompt) },
          {
            type: "input_image",
            image_url: toDataUrl(handBytes, contentTypeFromPath(job.hand_object_path)),
          },
          {
            type: "input_image",
            image_url: toDataUrl(referenceBytes, contentTypeFromPath(job.reference_object_path)),
          },
        ],
      },
    ],
    tools: [
      {
        type: "image_generation",
        model: "gpt-image-1",
      },
    ],
  };

  let response: Response;
  try {
    response = await fetch(OPENAI_RESPONSES_URL, {
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
    throw new WorkerError(code, `openai status=${response.status} body=${raw}`, retriable);
  }

  const json = await response.json() as {
    output?: Array<{
      type?: string;
      result?: string;
      b64_json?: string;
    }>;
  };
  const imageOutput = (json.output ?? []).find((item) => item.type === "image_generation_call");
  const b64 = imageOutput?.result ?? imageOutput?.b64_json;
  if (!b64) {
    const outputTypes = (json.output ?? []).map((item) => item.type ?? "unknown").join(",");
    throw new WorkerError(
      "OPENAI_BAD_RESPONSE",
      `missing image_generation result in responses output (types=${outputTypes || "none"})`,
      false,
    );
  }

  return decodeBase64(b64);
}

async function callOpenAIWithRetry(job: JobRow): Promise<Uint8Array> {
  const maxAttempts = 2;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await callOpenAI(job);
    } catch (e) {
      if (!(e instanceof WorkerError) || !e.retriable || attempt === maxAttempts) {
        throw e;
      }
      const backoffMs = 800 * attempt;
      await sleep(backoffMs);
    }
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
    .select("id, user_id, shape, user_prompt, hand_object_path, reference_object_path, attempt_count")
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
      completed_at: new Date().toISOString(),
      error_code: null,
      error_message: null,
    })
    .eq("id", job.id);

  if (error) {
    throw new WorkerError("JOB_COMPLETE_UPDATE_FAILED", error.message, false);
  }
}

async function failJob(jobId: string, code: string, message: string): Promise<void> {
  await supabaseAdmin
    .from("nail_generation_jobs")
    .update({
      status: "failed",
      error_code: code,
      error_message: truncate(message),
      completed_at: new Date().toISOString(),
    })
    .eq("id", jobId);
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
    .select("id, user_id, shape, user_prompt, hand_object_path, reference_object_path, attempt_count")
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

      const resultBytes = await callOpenAIWithRetry(claimed);
      const resultObjectPath = `${claimed.user_id}/${claimed.id}/result.png`;

      const { error: uploadError } = await supabaseAdmin.storage
        .from(RESULT_BUCKET)
        .upload(resultObjectPath, resultBytes, {
          contentType: "image/png",
          upsert: true,
        });

      if (uploadError) {
        throw new WorkerError("RESULT_UPLOAD_FAILED", uploadError.message, false);
      }

      await completeJob(claimed, resultObjectPath);
      completedCount += 1;
    } catch (e) {
      const normalized = normalizeError(e);
      const jobId = claimed?.id ?? job.id;
      await failJob(jobId, normalized.code, normalized.message);
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
