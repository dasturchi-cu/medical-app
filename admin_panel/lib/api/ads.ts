import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface AdItem {
  id: string;
  title: string;
  message: string;
  image_url: string;
  price_label: string;
  course_id: string;
  telegram: string;
  is_active: boolean;
  created_at: string;
}

function headers() {
  const { adminApiKey } = getApiConfig();
  return {
    "Content-Type": "application/json",
    ...(adminApiKey ? { "x-admin-api-key": adminApiKey } : {}),
  };
}

async function parseError(response: Response, fallback: string) {
  try {
    const data = (await response.json()) as { detail?: string };
    return data.detail?.trim() || fallback;
  } catch {
    return fallback;
  }
}

export async function fetchAds() {
  const response = await apiFetch("/api/v1/admin/ads", { cache: "no-store", headers: headers() });
  if (!response.ok) throw new Error(await parseError(response, "Reklamalarni olishda xatolik."));
  const data = (await response.json()) as { items: AdItem[] };
  return data.items ?? [];
}

export async function createAd(payload: {
  title: string;
  message: string;
  image_url: string;
  price_label: string;
  course_id: string;
  telegram: string;
}) {
  const response = await apiFetch("/api/v1/admin/ads", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reklama qo'shilmadi."));
  return (await response.json()) as AdItem;
}

export async function updateAd(adId: string, payload: Partial<Omit<AdItem, "id">>) {
  const response = await apiFetch(`/api/v1/admin/ads/${adId}`, {
    method: "PATCH",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reklama yangilanmadi."));
  return (await response.json()) as AdItem;
}

export async function removeAd(adId: string) {
  const response = await apiFetch(`/api/v1/admin/ads/${adId}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reklama o'chirilmadi."));
}
