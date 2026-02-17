import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { verify } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
};

type FeedPost = {
  id: string;
  title: string;
  thumbnail_url: string;
  like_count: number;
  shape_category: string;
  is_reservable: boolean;
  style_tags: string[] | null;
  studio_name: string;
  location_text: string;
  distance_km: number | null;
  original_price: number;
  discounted_price: number;
  duration_min: number;
  description: string;
  review_count: number;
  rating_avg: number;
  created_at: string;
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
  if (req.method !== "GET") return json(405, { message: "Method not allowed" });

  try {
    const userId = await requireUserId(req);
    const url = new URL(req.url);
    const postId = url.searchParams.get("post_id")?.trim().toLowerCase() ?? "";
    if (!isUuid(postId)) return json(400, { message: "post_id must be uuid" });

    const { data: post, error: postError } = await supabase
      .from("feed_posts")
      .select(
        "id, title, thumbnail_url, like_count, shape_category, is_reservable, style_tags, studio_name, location_text, distance_km, original_price, discounted_price, duration_min, description, review_count, rating_avg, created_at",
      )
      .eq("id", postId)
      .eq("status", "active")
      .maybeSingle();

    if (postError) return json(500, { message: `feed post lookup failed: ${postError.message}` });
    if (!post) return json(404, { message: "feed post not found" });

    const [{ data: images, error: imagesError }, { data: reviews, error: reviewsError }, { data: like, error: likeError }] = await Promise.all([
      supabase
        .from("feed_post_images")
        .select("image_url")
        .eq("post_id", postId)
        .order("sort_order", { ascending: true }),
      supabase
        .from("feed_post_reviews")
        .select("user_name, rating, comment, created_at")
        .eq("post_id", postId)
        .order("created_at", { ascending: false })
        .limit(3),
      supabase
        .from("feed_post_likes")
        .select("id")
        .eq("post_id", postId)
        .eq("user_id", userId)
        .maybeSingle(),
    ]);

    if (imagesError) return json(500, { message: `feed images lookup failed: ${imagesError.message}` });
    if (reviewsError) return json(500, { message: `feed reviews lookup failed: ${reviewsError.message}` });
    if (likeError && likeError.code !== "PGRST116") {
      return json(500, { message: `feed like lookup failed: ${likeError.message}` });
    }

    const galleryImageURLs = (images ?? [])
      .map((row) => (row as { image_url?: string }).image_url)
      .filter((v): v is string => !!v && v.length > 0);

    const postData = post as FeedPost;

    return json(200, {
      post: {
        id: postData.id,
        title: postData.title,
        thumbnail_url: postData.thumbnail_url,
        like_count: postData.like_count,
        shape_category: postData.shape_category,
        is_reservable: postData.is_reservable,
        is_liked: !!like,
        style_tags: postData.style_tags ?? [],
        studio_name: postData.studio_name,
        location_text: postData.location_text,
        distance_km: postData.distance_km,
        original_price: postData.original_price,
        discounted_price: postData.discounted_price,
        duration_min: postData.duration_min,
        description: postData.description,
        review_count: postData.review_count,
        rating_avg: postData.rating_avg,
        created_at: postData.created_at,
      },
      gallery_image_urls: galleryImageURLs,
      recent_reviews: (reviews ?? []).map((row) => {
        const review = row as {
          user_name: string;
          rating: number;
          comment: string;
          created_at: string;
        };
        return {
          user_name: review.user_name,
          rating: review.rating,
          comment: review.comment,
          created_at: review.created_at,
        };
      }),
    });
  } catch (e) {
    return json(401, { message: e instanceof Error ? e.message : "Unknown error" });
  }
});
