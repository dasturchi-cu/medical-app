import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface BannerItem {
  id: string;
  title: string;
  message: string;
  image_url: string;
  price_label: string;
  course_id: string | null;
  telegram: string;
  is_active: boolean;
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

export async function fetchBanners() {
  const response = await apiFetch("/api/v1/banners", { cache: "no-store" });
  if (!response.ok) throw new Error(await parseError(response, "Reklamalarni olishda xatolik."));
  const data = (await response.json()) as { items: BannerItem[] };
  return data.items ?? [];
}

export async function createBanner(payload: {
  title: string;
  message: string;
  image_url: string;
  price_label: string;
  course_id?: string | null;
  telegram: string;
  is_active?: boolean;
}) {
  const response = await apiFetch("/api/v1/banners", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reklama qo'shilmadi."));
  return (await response.json()) as BannerItem;
}

export async function updateBanner(id: string, payload: Partial<Omit<BannerItem, "id">>) {
  const response = await apiFetch(`/api/v1/banners/${id}`, {
    method: "PATCH",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reklama yangilanmadi."));
  return (await response.json()) as BannerItem;
}

export async function removeBanner(id: string) {
  const response = await apiFetch(`/api/v1/banners/${id}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reklama o'chirilmadi."));
}
