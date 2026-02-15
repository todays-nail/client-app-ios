import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { errorResponse, jsonResponse, readJson } from "../_shared/http.ts";
import { getKakaoUserIdFromAccessToken } from "../_shared/kakao.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";
import { signAccessJwt } from "../_shared/jwt.ts";
import { generateRefreshToken, hashRefreshToken } from "../_shared/refresh.ts";

type ReqBody = {
  kakaoAccessToken?: string;
  deviceId?: string;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  try {
    const body = await readJson<ReqBody>(req);
    const kakaoAccessToken = body.kakaoAccessToken?.trim() ?? "";
    const deviceId = body.deviceId?.trim() ?? "";
    if (!kakaoAccessToken) return errorResponse(400, "kakaoAccessToken is required");
    if (!deviceId) return errorResponse(400, "deviceId is required");

    const kakaoUserId = await getKakaoUserIdFromAccessToken(kakaoAccessToken);

    // upsert users by kakao_user_id (닉네임/전화번호/프로필은 온보딩에서 설정)
    // NOTE: do not write/select `role` here to avoid hard-coupling to a column that may not exist
    // (or may not be refreshed in PostgREST schema cache yet). DB default can handle it.
    const { data: user, error: userError } = await supabaseAdmin
      .from("users")
      .upsert({ kakao_user_id: kakaoUserId }, { onConflict: "kakao_user_id" })
      .select("id, nickname, phone, profile_image_url, created_at, updated_at")
      .single();
    if (userError) return errorResponse(500, `users upsert failed: ${userError.message}`);

    const accessToken = await signAccessJwt({
      userId: user.id,
      kakaoUserId,
      role: "USER",
    });

    const refreshToken = generateRefreshToken();
    const tokenHash = await hashRefreshToken(refreshToken);
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

    const { error: rtError } = await supabaseAdmin
      .from("user_refresh_tokens")
      .insert({
        user_id: user.id,
        device_id: deviceId,
        token_hash: tokenHash,
        expires_at: expiresAt,
      });
    if (rtError) return errorResponse(500, `refresh token insert failed: ${rtError.message}`);

    const nickname = (user.nickname ?? "").trim();
    const needsOnboarding = nickname.length === 0;

    return jsonResponse(200, {
      accessToken,
      refreshToken,
      user,
      needsOnboarding,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    return errorResponse(401, msg);
  }
});
