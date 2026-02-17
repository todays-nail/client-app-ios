import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import {
  errorResponse,
  getBearerToken,
  jsonResponse,
} from "../_shared/http.ts";
import { verifyAccessJwt } from "../_shared/jwt.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

type CursorPayload = {
  created_at: string;
  id: string;
};

type FeedCategory = "all" | "style" | "reservable";

type FeedRow = {
  id: string;
  thumbnail_url: string;
  like_count: number;
  shape_category: string;
  is_reservable: boolean;
  style_tags: string[] | null;
  created_at: string;
};

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function parseLimit(raw: string | null): number {
  if (!raw) return 20;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1 || n > 50) {
    throw new Error("limit must be integer between 1 and 50");
  }
  return n;
}

function parseCategory(raw: string | null): FeedCategory {
  if (!raw || raw.trim().length === 0) return "all";
  if (raw === "all" || raw === "style" || raw === "reservable") return raw;
  throw new Error("category must be one of: all, style, reservable");
}

function parseStyles(raw: string | null): string[] {
  if (!raw) return [];
  const styles = raw
    .split(",")
    .map((v) => v.trim())
    .filter((v) => v.length > 0);

  const unique = Array.from(new Set(styles));
  if (unique.length > 3) {
    throw new Error("styles supports up to 3 values");
  }
  return unique;
}

function decodeCursor(raw: string | null): CursorPayload | null {
  if (!raw) return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(atob(raw));
  } catch {
    throw new Error("cursor is invalid");
  }

  if (!parsed || typeof parsed !== "object") {
    throw new Error("cursor is invalid");
  }

  const createdAt = (parsed as Record<string, unknown>)["created_at"];
  const id = (parsed as Record<string, unknown>)["id"];
  if (
    typeof createdAt !== "string" ||
    Number.isNaN(Date.parse(createdAt)) ||
    typeof id !== "string" ||
    !isUuid(id)
  ) {
    throw new Error("cursor is invalid");
  }

  return { created_at: createdAt, id: id.toLowerCase() };
}

function encodeCursor(row: FeedRow): string {
  return btoa(JSON.stringify({ created_at: row.created_at, id: row.id }));
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

    const limit = parseLimit(url.searchParams.get("limit"));
    const category = parseCategory(url.searchParams.get("category"));
    const styles = parseStyles(url.searchParams.get("styles"));
    const cursor = decodeCursor(url.searchParams.get("cursor"));

    const hasReservationFilter =
      !!url.searchParams.get("reservation_date") ||
      !!url.searchParams.get("start_time") ||
      !!url.searchParams.get("end_time");

    let query = supabaseAdmin
      .from("feed_posts")
      .select("id, thumbnail_url, like_count, shape_category, is_reservable, style_tags, created_at")
      .eq("status", "active")
      .order("created_at", { ascending: false })
      .order("id", { ascending: false });

    if (category === "reservable" || hasReservationFilter) {
      query = query.eq("is_reservable", true);
    } else if (category === "style") {
      query = query.eq("is_reservable", false);
    }

    if (styles.length > 0) {
      query = query.overlaps("style_tags", styles);
    }

    if (cursor) {
      query = query.lte("created_at", cursor.created_at);
    }

    const fetchLimit = Math.min(200, limit + 50);
    const { data, error } = await query.limit(fetchLimit);
    if (error) return errorResponse(500, `feed list lookup failed: ${error.message}`);

    const sourceRows = (data ?? []) as FeedRow[];

    const rows = cursor
      ? sourceRows.filter((row) => {
        if (row.created_at < cursor.created_at) return true;
        if (row.created_at > cursor.created_at) return false;
        return row.id.toLowerCase() < cursor.id;
      })
      : sourceRows;

    const pageRows = rows.slice(0, limit);
    const postIds = pageRows.map((row) => row.id);

    const likedIds = new Set<string>();
    if (postIds.length > 0) {
      const { data: likes, error: likesError } = await supabaseAdmin
        .from("bookmarks")
        .select("reference_id")
        .eq("user_id", userId)
        .in("reference_id", postIds);

      if (likesError) {
        return errorResponse(500, `feed likes lookup failed: ${likesError.message}`);
      }

      for (const like of likes ?? []) {
        const postId = (like as { reference_id?: string }).reference_id;
        if (postId) likedIds.add(postId);
      }
    }

    const items = pageRows.map((row) => ({
      id: row.id,
      thumbnail_url: row.thumbnail_url,
      like_count: row.like_count,
      shape_category: row.shape_category,
      is_reservable: row.is_reservable,
      is_liked: likedIds.has(row.id),
      style_tags: row.style_tags ?? [],
      created_at: row.created_at,
    }));

    const nextCursor = pageRows.length == limit
      ? encodeCursor(pageRows[pageRows.length - 1])
      : null;

    return jsonResponse(200, {
      items,
      next_cursor: nextCursor,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    if (
      message.includes("limit") ||
      message.includes("category") ||
      message.includes("styles") ||
      message.includes("cursor")
    ) {
      return errorResponse(400, message);
    }
    return errorResponse(401, message);
  }
});
