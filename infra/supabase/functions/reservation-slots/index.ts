import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import {
  errorResponse,
  getBearerToken,
  jsonResponse,
} from "../_shared/http.ts";
import { verifyAccessJwt } from "../_shared/jwt.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

type ReferenceRow = {
  id: string;
  shop_id: string;
  service_duration_min: number;
  is_active: boolean;
  is_reservable: boolean;
};

type SlotRow = {
  id: string;
  shop_id: string;
  start_at: string;
  duration_min: number;
  capacity: number;
  status: string;
};

const ACTIVE_RESERVATION_STATUSES = [
  "PENDING_DEPOSIT",
  "DEPOSIT_PAID",
  "CONFIRMED",
  "SERVICE_CONFIRMED",
  "BALANCE_PAID",
  "COMPLETED",
];

const DAY_MS = 24 * 60 * 60 * 1000;

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function formatDateUTC(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function parseFromDate(raw: string | null): Date {
  const normalized = raw?.trim() ?? "";
  if (!normalized) {
    const now = new Date();
    return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  }

  if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
    throw new Error("from_date must be yyyy-mm-dd");
  }

  const parsed = new Date(`${normalized}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error("from_date must be yyyy-mm-dd");
  }

  return parsed;
}

function parseDays(raw: string | null): number {
  if (!raw) return 7;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1 || n > 14) {
    throw new Error("days must be integer between 1 and 14");
  }
  return n;
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
    await requireUserId(req);

    const url = new URL(req.url);
    const referenceId = url.searchParams.get("reference_id")?.trim().toLowerCase() ?? "";
    if (!isUuid(referenceId)) return errorResponse(400, "reference_id must be uuid");

    const fromDate = parseFromDate(url.searchParams.get("from_date"));
    const days = parseDays(url.searchParams.get("days"));
    const rangeStart = fromDate.toISOString();
    const rangeEnd = new Date(fromDate.getTime() + days * DAY_MS).toISOString();

    const { data: reference, error: referenceError } = await supabaseAdmin
      .from("references")
      .select("id, shop_id, service_duration_min, is_active, is_reservable")
      .eq("id", referenceId)
      .maybeSingle();

    if (referenceError) return errorResponse(500, `reference lookup failed: ${referenceError.message}`);
    if (!reference) return errorResponse(404, "reference not found");

    const referenceData = reference as ReferenceRow;
    if (!referenceData.is_active || !referenceData.is_reservable) {
      return errorResponse(400, "reference is not reservable");
    }

    const { data: slots, error: slotsError } = await supabaseAdmin
      .from("slots")
      .select("id, shop_id, start_at, duration_min, capacity, status")
      .eq("shop_id", referenceData.shop_id)
      .eq("status", "OPEN")
      .gte("start_at", rangeStart)
      .lt("start_at", rangeEnd)
      .gte("duration_min", Math.max(1, referenceData.service_duration_min || 1))
      .order("start_at", { ascending: true });

    if (slotsError) return errorResponse(500, `slot lookup failed: ${slotsError.message}`);

    const slotRows = (slots ?? []) as SlotRow[];
    const slotIds = slotRows.map((slot) => slot.id);

    const reservedSlotIds = new Set<string>();
    if (slotIds.length > 0) {
      const { data: reservations, error: reservationsError } = await supabaseAdmin
        .from("reservations")
        .select("slot_id")
        .in("slot_id", slotIds)
        .in("status", ACTIVE_RESERVATION_STATUSES);

      if (reservationsError) {
        return errorResponse(500, `slot reservation lookup failed: ${reservationsError.message}`);
      }

      for (const row of reservations ?? []) {
        const slotId = (row as { slot_id?: string }).slot_id;
        if (slotId) reservedSlotIds.add(slotId);
      }
    }

    const availableSlots = slotRows
      .filter((slot) => !reservedSlotIds.has(slot.id))
      .map((slot) => ({
        id: slot.id,
        shop_id: slot.shop_id,
        start_at: slot.start_at,
        duration_min: slot.duration_min,
        capacity: slot.capacity,
        status: slot.status,
      }));

    return jsonResponse(200, {
      reference_id: referenceData.id,
      shop_id: referenceData.shop_id,
      required_duration_min: Math.max(1, referenceData.service_duration_min || 1),
      from_date: formatDateUTC(fromDate),
      days,
      slots: availableSlots,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    if (message.includes("from_date") || message.includes("days")) {
      return errorResponse(400, message);
    }
    return errorResponse(401, message);
  }
});
