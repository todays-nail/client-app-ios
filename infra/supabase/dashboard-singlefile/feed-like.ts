import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.95.3";
import { verify } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, DELETE, OPTIONS",
};

type FeedLikeBody = {
  post_id?: string;
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

async function readJson<T>(req: Request): Promise<T> {
  const text = await req.text();
  if (!text) return {} as T;
  return JSON.parse(text) as T;
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
  if (req.method !== "POST" && req.method !== "DELETE") return json(405, { message: "Method not allowed" });

  try {
    const userId = await requireUserId(req);
    const body = await readJson<FeedLikeBody>(req);
    const postId = body.post_id?.trim().toLowerCase() ?? "";

    if (!isUuid(postId)) {
      return json(400, { message: "post_id must be uuid" });
    }

    const { data: post, error: postError } = await supabase
      .from("feed_posts")
      .select("id")
      .eq("id", postId)
      .eq("status", "active")
      .maybeSingle();

    if (postError) {
      return json(500, { message: `feed post lookup failed: ${postError.message}` });
    }

    if (!post) {
      return json(404, { message: "feed post not found" });
    }

    if (req.method === "POST") {
      const { data: existingLike, error: existingLikeError } = await supabase
        .from("bookmarks")
        .select("reference_id")
        .eq("user_id", userId)
        .eq("reference_id", postId)
        .maybeSingle();

      if (existingLikeError && existingLikeError.code !== "PGRST116") {
        return json(500, { message: `feed like lookup failed: ${existingLikeError.message}` });
      }

      if (!existingLike) {
        const { error: insertError } = await supabase
          .from("bookmarks")
          .insert({
            user_id: userId,
            reference_id: postId,
          });

        if (insertError) {
          return json(500, { message: `feed like save failed: ${insertError.message}` });
        }
      }
    } else {
      const { error: deleteError } = await supabase
        .from("bookmarks")
        .delete()
        .eq("user_id", userId)
        .eq("reference_id", postId);

      if (deleteError) {
        return json(500, { message: `feed like delete failed: ${deleteError.message}` });
      }
    }

    const [{ data: like, error: likeError }, { data: likeCountRow, error: likeCountError }] = await Promise.all([
      supabase
        .from("bookmarks")
        .select("reference_id")
        .eq("user_id", userId)
        .eq("reference_id", postId)
        .maybeSingle(),
      supabase
        .from("feed_posts")
        .select("like_count")
        .eq("id", postId)
        .single(),
    ]);

    if (likeError && likeError.code !== "PGRST116") {
      return json(500, { message: `feed like lookup failed: ${likeError.message}` });
    }

    if (likeCountError) {
      return json(500, { message: `feed post lookup failed: ${likeCountError.message}` });
    }

    return json(200, {
      ok: true,
      post_id: postId,
      is_liked: !!like,
      like_count: (likeCountRow as { like_count?: number } | null)?.like_count ?? 0,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    return json(401, { message });
  }
});
