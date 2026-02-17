import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.95.3";
import { verify } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type UploadKind = "hand" | "reference" | "profile";

type ReqBody = {
  kind?: UploadKind;
  ext?: string;
  content_type?: string;
  bytes?: number;
  job_id?: string;
};

const INPUT_BUCKET = "nail-inputs-private";
const PROFILE_BUCKET = "profile-images-public";
const EXPIRES_IN_SEC = 10 * 60;
const MAX_UPLOAD_BYTES = 15 * 1024 * 1024;
const ALLOWED_EXTENSIONS = new Set(["jpg", "jpeg", "png", "webp"]);
const ALLOWED_CONTENT_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);

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

function publicObjectUrl(bucket: string, objectPath: string): string {
  const supabaseUrl = requireEnv("SUPABASE_URL").replace(/\/+$/, "");
  const encodedPath = objectPath
    .split("/")
    .map((segment) => encodeURIComponent(segment))
    .join("/");
  return `${supabaseUrl}/storage/v1/object/public/${bucket}/${encodedPath}`;
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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json(405, { message: "Method not allowed" });

  try {
    const userId = await requireUserId(req);
    const body = await readJson<ReqBody>(req);

    const kind = body.kind;
    const ext = body.ext?.trim().toLowerCase() ?? "";
    const contentType = body.content_type?.trim().toLowerCase() ?? "";
    const bytes = body.bytes;
    const requestedJobId = body.job_id?.trim() ?? "";

    if (kind !== "hand" && kind !== "reference" && kind !== "profile") {
      return json(400, { message: "kind must be one of: hand, reference, profile" });
    }
    if (!ALLOWED_EXTENSIONS.has(ext)) {
      return json(400, { message: "unsupported ext" });
    }
    if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
      return json(400, { message: "unsupported content_type" });
    }
    if (typeof bytes !== "number" || !Number.isFinite(bytes) || bytes <= 0) {
      return json(400, { message: "bytes must be a positive number" });
    }
    if (bytes > MAX_UPLOAD_BYTES) {
      return json(400, { message: `bytes exceeds max limit (${MAX_UPLOAD_BYTES})` });
    }

    const jobId = requestedJobId || crypto.randomUUID();
    if (!isUuid(jobId)) {
      return json(400, { message: "job_id must be uuid format" });
    }

    const isProfile = kind === "profile";
    const filename = kind === "hand" ? "hand" : (kind === "reference" ? "reference_1" : "profile");
    const bucket = isProfile ? PROFILE_BUCKET : INPUT_BUCKET;
    const objectPath = isProfile
      ? `${userId}/profile/${jobId}.${ext}`
      : `${userId}/${jobId}/${filename}.${ext}`;

    const { data, error } = await supabase.storage
      .from(bucket)
      .createSignedUploadUrl(objectPath, EXPIRES_IN_SEC);

    if (error || !data?.signedUrl) {
      return json(500, { message: `createSignedUploadUrl failed: ${error?.message ?? "unknown"}` });
    }

    return json(200, {
      bucket,
      job_id: jobId,
      object_path: objectPath,
      signed_upload_url: absolutizeUploadUrl(data.signedUrl),
      public_object_url: isProfile ? publicObjectUrl(bucket, objectPath) : null,
      expires_in_sec: EXPIRES_IN_SEC,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    return json(401, { message });
  }
});
