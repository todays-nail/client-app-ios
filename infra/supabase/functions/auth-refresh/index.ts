import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { errorResponse, jsonResponse, readJson } from "../_shared/http.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";
import { generateRefreshToken, hashRefreshToken } from "../_shared/refresh.ts";
import { signAccessJwt } from "../_shared/jwt.ts";

type ReqBody = {
  refreshToken?: string;
  deviceId?: string;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  try {
    const body = await readJson<ReqBody>(req);
    const refreshToken = body.refreshToken?.trim() ?? "";
    const deviceId = body.deviceId?.trim() ?? "";
    if (!refreshToken) return errorResponse(400, "refreshToken is required");
    if (!deviceId) return errorResponse(400, "deviceId is required");

    const tokenHash = await hashRefreshToken(refreshToken);
    const { data: row, error: rowError } = await supabaseAdmin
      .from("user_refresh_tokens")
      .select("id, user_id, expires_at, revoked_at")
      .eq("token_hash", tokenHash)
      .eq("device_id", deviceId)
      .maybeSingle();

    if (rowError) return errorResponse(500, `refresh token lookup failed: ${rowError.message}`);
    if (!row) return errorResponse(401, "invalid refresh token");
    if (row.revoked_at) return errorResponse(401, "refresh token revoked");
    if (new Date(row.expires_at).getTime() <= Date.now()) return errorResponse(401, "refresh token expired");

    // NOTE: do not read `role` to avoid hard dependency on the column.
    const { data: user, error: userError } = await supabaseAdmin
      .from("users")
      .select("id, kakao_user_id")
      .eq("id", row.user_id)
      .single();
    if (userError) return errorResponse(500, `user lookup failed: ${userError.message}`);

    // Rotation: revoke old, mint new
    const newRefreshToken = generateRefreshToken();
    const newHash = await hashRefreshToken(newRefreshToken);
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

    const { data: inserted, error: insertError } = await supabaseAdmin
      .from("user_refresh_tokens")
      .insert({
        user_id: row.user_id,
        device_id: deviceId,
        token_hash: newHash,
        expires_at: expiresAt,
      })
      .select("id")
      .single();
    if (insertError) return errorResponse(500, `refresh token insert failed: ${insertError.message}`);

    const { error: revokeError } = await supabaseAdmin
      .from("user_refresh_tokens")
      .update({ revoked_at: new Date().toISOString(), replaced_by: inserted.id })
      .eq("id", row.id);
    if (revokeError) return errorResponse(500, `refresh token revoke failed: ${revokeError.message}`);

    const accessToken = await signAccessJwt({
      userId: user.id,
      kakaoUserId: user.kakao_user_id,
      role: "USER",
    });

    return jsonResponse(200, { accessToken, refreshToken: newRefreshToken });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    return errorResponse(401, msg);
  }
});
