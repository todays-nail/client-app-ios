import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import {
  errorResponse,
  getBearerToken,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";
import { verifyAccessJwt } from "../_shared/jwt.ts";

type PatchBody = {
  nickname?: string;
  phone?: string | null;
  profile_image_url?: string | null;
};

type UserRow = {
  id: string;
  nickname: string | null;
  phone: string | null;
  profile_image_url: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

async function requireUserId(req: Request): Promise<string> {
  const token = getBearerToken(req);
  if (!token) throw new Error("missing bearer token");
  const payload = await verifyAccessJwt(token);
  const sub = payload["sub"];
  if (!sub || typeof sub !== "string") throw new Error("invalid token payload");
  return sub;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userId = await requireUserId(req);

    if (req.method === "GET") {
      const { data: user, error } = await supabaseAdmin
        .from("users")
        .select("id, nickname, phone, profile_image_url, created_at, updated_at, deleted_at")
        .eq("id", userId)
        .single();
      if (error) return errorResponse(500, `users lookup failed: ${error.message}`);
      const userRow = user as UserRow;
      if (userRow.deleted_at) return errorResponse(403, "account is deleted");

      const nickname = (userRow.nickname ?? "").trim();
      const { deleted_at: _, ...safeUser } = userRow;
      const needsOnboarding = nickname.length === 0;
      return jsonResponse(200, { user: safeUser, needsOnboarding });
    }

    if (req.method === "PATCH") {
      const { data: existing, error: existingError } = await supabaseAdmin
        .from("users")
        .select("deleted_at")
        .eq("id", userId)
        .single();
      if (existingError) return errorResponse(500, `users lookup failed: ${existingError.message}`);
      if ((existing as { deleted_at: string | null }).deleted_at) return errorResponse(403, "account is deleted");

      const body = await readJson<PatchBody>(req);
      const nickname = body.nickname?.trim();

      if (nickname !== undefined && nickname.length === 0) {
        return errorResponse(400, "nickname must be non-empty");
      }

      const patch: Record<string, unknown> = {};
      if (nickname !== undefined) patch["nickname"] = nickname;
      if (body.phone !== undefined) patch["phone"] = body.phone;
      if (body.profile_image_url !== undefined) {
        patch["profile_image_url"] = body.profile_image_url;
      }

      const { data: user, error } = await supabaseAdmin
        .from("users")
        .update(patch)
        .eq("id", userId)
        .select("id, nickname, phone, profile_image_url, created_at, updated_at, deleted_at")
        .single();
      if (error) return errorResponse(500, `users update failed: ${error.message}`);
      const userRow = user as UserRow;
      if (userRow.deleted_at) return errorResponse(403, "account is deleted");

      const nn = (userRow.nickname ?? "").trim();
      const { deleted_at: _, ...safeUser } = userRow;
      const needsOnboarding = nn.length === 0;
      return jsonResponse(200, { user: safeUser, needsOnboarding });
    }

    return errorResponse(405, "Method not allowed");
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    return errorResponse(401, msg);
  }
});
