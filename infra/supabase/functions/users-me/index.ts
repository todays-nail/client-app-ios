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
        .select("id, nickname, phone, profile_image_url, created_at, updated_at")
        .eq("id", userId)
        .single();
      if (error) return errorResponse(500, `users lookup failed: ${error.message}`);

      const nickname = (user.nickname ?? "").trim();
      const needsOnboarding = nickname.length === 0;
      return jsonResponse(200, { user, needsOnboarding });
    }

    if (req.method === "PATCH") {
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
        .select("id, nickname, phone, profile_image_url, created_at, updated_at")
        .single();
      if (error) return errorResponse(500, `users update failed: ${error.message}`);

      const nn = (user.nickname ?? "").trim();
      const needsOnboarding = nn.length === 0;
      return jsonResponse(200, { user, needsOnboarding });
    }

    return errorResponse(405, "Method not allowed");
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    return errorResponse(401, msg);
  }
});
