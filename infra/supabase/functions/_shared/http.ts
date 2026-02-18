import { corsHeaders, withCors } from "./cors.ts";

export type Json = Record<string, unknown> | unknown[] | string | number | null;

export function jsonResponse(status: number, body: Json): Response {
  return withCors(
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    }),
  );
}

export function errorResponse(status: number, message: string): Response {
  return jsonResponse(status, { message });
}

export async function readJson<T>(req: Request): Promise<T> {
  const text = await req.text();
  if (!text) return {} as T;
  return JSON.parse(text) as T;
}

export function getBearerToken(req: Request): string | null {
  const auth = req.headers.get("authorization") ?? req.headers.get("Authorization");
  if (!auth) return null;
  const m = auth.match(/^Bearer\s+(.+)$/i);
  let token = (m?.[1] ?? auth).trim();
  token = token.replace(/[\r\n\t ]+/g, "");

  if (!token) return null;
  if (token.startsWith('"') && token.endsWith('"') && token.length > 1) {
    token = token.slice(1, -1).trim();
  }

  return token || null;
}
