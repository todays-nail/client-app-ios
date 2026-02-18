import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { errorResponse, jsonResponse, readJson } from "../_shared/http.ts";
import { getKakaoProfileFromAccessToken } from "../_shared/kakao.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";
import { signAccessJwt } from "../_shared/jwt.ts";
import { generateRefreshToken, hashRefreshToken } from "../_shared/refresh.ts";

type ReqBody = {
  kakaoAccessToken?: string;
  deviceId?: string;
};

const ACCESS_TOKEN_TTL_SEC = 15 * 60;
const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse(405, "Method not allowed", "AUTH_METHOD_NOT_ALLOWED");
  }

  try {
    const body = await readJson<ReqBody>(req);
    const kakaoAccessToken = body.kakaoAccessToken?.trim() ?? "";
    const deviceId = body.deviceId?.trim() ?? "";
    if (!kakaoAccessToken) {
      return errorResponse(400, "kakaoAccessToken is required", "AUTH_KAKAO_TOKEN_REQUIRED");
    }
    if (!deviceId) return errorResponse(400, "deviceId is required", "AUTH_DEVICE_ID_REQUIRED");

    const kakaoProfile = await getKakaoProfileFromAccessToken(kakaoAccessToken);
    const kakaoUserId = kakaoProfile.id;

    const { data: existingUser, error: existingUserError } = await supabaseAdmin
      .from("users")
      .select("id, deleted_at")
      .eq("kakao_user_id", kakaoUserId)
      .maybeSingle();
    if (existingUserError) {
      return errorResponse(
        500,
        `users lookup failed: ${existingUserError.message}`,
        "AUTH_USER_LOOKUP_FAILED",
      );
    }
    if (existingUser?.deleted_at) {
      return errorResponse(403, "account is deleted", "AUTH_ACCOUNT_DELETED");
    }

    // upsert users by kakao_user_id (닉네임/전화번호/프로필은 온보딩에서 설정)
    // NOTE: do not write/select `role` here to avoid hard-coupling to a column that may not exist
    // (or may not be refreshed in PostgREST schema cache yet). DB default can handle it.
    const { data: user, error: userError } = await supabaseAdmin
      .from("users")
      .upsert({ kakao_user_id: kakaoUserId }, { onConflict: "kakao_user_id" })
      .select("id, nickname, phone, profile_image_url, created_at, updated_at")
      .single();
    if (userError) {
      return errorResponse(500, `users upsert failed: ${userError.message}`, "AUTH_USER_UPSERT_FAILED");
    }

    const now = Date.now();
    const accessTokenExpiresAt = new Date(now + ACCESS_TOKEN_TTL_SEC * 1000).toISOString();
    const refreshTokenExpiresAt = new Date(now + REFRESH_TOKEN_TTL_MS).toISOString();

    const accessToken = await signAccessJwt({
      userId: user.id,
      kakaoUserId,
      role: "USER",
      expiresInSeconds: ACCESS_TOKEN_TTL_SEC,
    });

    const refreshToken = generateRefreshToken();
    const tokenHash = await hashRefreshToken(refreshToken);

    // Device policy: keep a single active refresh token per user/device.
    const { error: revokeError } = await supabaseAdmin
      .from("user_refresh_tokens")
      .update({ revoked_at: new Date(now).toISOString() })
      .eq("user_id", user.id)
      .eq("device_id", deviceId)
      .is("revoked_at", null);
    if (revokeError) {
      return errorResponse(500, `refresh token revoke failed: ${revokeError.message}`, "AUTH_REFRESH_REVOKE_FAILED");
    }

    const { data: insertedToken, error: rtError } = await supabaseAdmin
      .from("user_refresh_tokens")
      .insert({
        user_id: user.id,
        device_id: deviceId,
        token_hash: tokenHash,
        expires_at: refreshTokenExpiresAt,
      })
      .select("id")
      .single();
    if (rtError) {
      return errorResponse(500, `refresh token insert failed: ${rtError.message}`, "AUTH_REFRESH_INSERT_FAILED");
    }

    const nickname = (user.nickname ?? "").trim();
    const needsOnboarding = nickname.length === 0;

    return jsonResponse(200, {
      accessToken,
      refreshToken,
      access_token_expires_at: accessTokenExpiresAt,
      refresh_token_expires_at: refreshTokenExpiresAt,
      session_id: insertedToken.id,
      user,
      needsOnboarding,
      onboarding_prefill: {
        nickname: kakaoProfile.nickname,
        profile_image_url: kakaoProfile.profileImageURL,
      },
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    return errorResponse(401, msg, "AUTH_KAKAO_VERIFY_FAILED");
  }
});
