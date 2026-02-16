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
import { requireEnv } from "../_shared/env.ts";

type UploadKind = "hand" | "reference";

type ReqBody = {
  kind?: UploadKind;
  ext?: string;
  content_type?: string;
  bytes?: number;
  job_id?: string;
};

const INPUT_BUCKET = "nail-inputs-private";
const EXPIRES_IN_SEC = 10 * 60;
const MAX_UPLOAD_BYTES = 15 * 1024 * 1024;
const ALLOWED_EXTENSIONS = new Set(["jpg", "jpeg", "png", "webp"]);
const ALLOWED_CONTENT_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function absolutizeUploadUrl(signedUrl: string): string {
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

  return sub;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  try {
    const userId = await requireUserId(req);
    const body = await readJson<ReqBody>(req);

    const kind = body.kind;
    const ext = body.ext?.trim().toLowerCase() ?? "";
    const contentType = body.content_type?.trim().toLowerCase() ?? "";
    const bytes = body.bytes;
    const requestedJobId = body.job_id?.trim() ?? "";

    if (kind !== "hand" && kind !== "reference") {
      return errorResponse(400, "kind must be one of: hand, reference");
    }
    if (!ALLOWED_EXTENSIONS.has(ext)) {
      return errorResponse(400, "unsupported ext");
    }
    if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
      return errorResponse(400, "unsupported content_type");
    }
    if (typeof bytes !== "number" || !Number.isFinite(bytes) || bytes <= 0) {
      return errorResponse(400, "bytes must be a positive number");
    }
    if (bytes > MAX_UPLOAD_BYTES) {
      return errorResponse(400, `bytes exceeds max limit (${MAX_UPLOAD_BYTES})`);
    }

    const jobId = requestedJobId || crypto.randomUUID();
    if (!isUuid(jobId)) {
      return errorResponse(400, "job_id must be uuid format");
    }

    const filename = kind === "hand" ? "hand" : "reference_1";
    const objectPath = `${userId}/${jobId}/${filename}.${ext}`;

    const { data, error } = await supabaseAdmin.storage
      .from(INPUT_BUCKET)
      .createSignedUploadUrl(objectPath, EXPIRES_IN_SEC);

    if (error || !data?.signedUrl) {
      return errorResponse(500, `createSignedUploadUrl failed: ${error?.message ?? "unknown"}`);
    }

    return jsonResponse(200, {
      bucket: INPUT_BUCKET,
      job_id: jobId,
      object_path: objectPath,
      signed_upload_url: absolutizeUploadUrl(data.signedUrl),
      expires_in_sec: EXPIRES_IN_SEC,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    return errorResponse(401, message);
  }
});
