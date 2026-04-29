import { getApiConfig } from "@/lib/api/config";

export interface SlideItem {
  id: string;
  title: string;
  subtitle: string;
  image_url: string;
  button_text: string;
  course_id: string | null;
  order_no: number;
  is_active: boolean;
  created_at: string;
}

function endpoint(path: string) {
  const { apiBaseUrl } = getApiConfig();
  return `${apiBaseUrl}${path}`;
}

function headers() {
  const { adminApiKey } = getApiConfig();
  return {
    "Content-Type": "application/json",
    ...(adminApiKey ? { "x-admin-api-key": adminApiKey } : {}),
  };
}

export async function fetchSlides() {
  const response = await fetch(endpoint("/api/v1/slides"), { cache: "no-store" });
  if (!response.ok) throw new Error("Slaydlarni olishda xatolik.");
  const data = (await response.json()) as { items: SlideItem[] };
  return data.items ?? [];
}

export async function createSlide(payload: {
  title: string;
  subtitle: string;
  image_url: string;
  button_text: string;
  order_no: number;
  course_id?: string | null;
}) {
  const response = await fetch(endpoint("/api/v1/slides"), {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error("Slayd qo'shishda xatolik.");
  return (await response.json()) as SlideItem;
}

export async function deleteSlide(id: string) {
  const response = await fetch(endpoint(`/api/v1/slides/${id}`), {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error("Slayd o'chirishda xatolik.");
}
