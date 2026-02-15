export async function getKakaoUserIdFromAccessToken(
  kakaoAccessToken: string,
): Promise<string> {
  const resp = await fetch("https://kapi.kakao.com/v2/user/me", {
    method: "GET",
    headers: {
      Authorization: `Bearer ${kakaoAccessToken}`,
      "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
    },
  });

  if (!resp.ok) {
    const text = await resp.text().catch(() => "");
    throw new Error(`Kakao verify failed: ${resp.status} ${text}`);
  }

  const data = await resp.json() as { id?: number | string };
  if (data?.id === undefined || data?.id === null) {
    throw new Error("Kakao verify failed: missing id");
  }
  return String(data.id);
}

