import { getApiConfig } from "@/lib/api/config";

export interface LessonSlideItem {
  id: string;
  lesson_id: string;
  title: string;
  body: string;
  image_url: string;
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

export async function fetchLessonSlides(lessonId: string) {
  if (!lessonId) return [] as LessonSlideItem[];
  const response = await fetch(endpoint(`/api/v1/lesson-slides?lesson_id=${lessonId}&active_only=false`), {
    cache: "no-store",
  });
  if (!response.ok) throw new Error("Slaydlarni olishda xatolik.");
  const data = (await response.json()) as { items: LessonSlideItem[] };
  return data.items ?? [];
}

export async function createLessonSlide(payload: {
  lesson_id: string;
  title: string;
  body: string;
  image_url: string;
  order_no: number;
}) {
  const response = await fetch(endpoint("/api/v1/lesson-slides"), {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error("Slayd qo'shishda xatolik.");
  return (await response.json()) as LessonSlideItem;
}

export async function deleteLessonSlide(id: string) {
  const response = await fetch(endpoint(`/api/v1/lesson-slides/${id}`), {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error("Slayd o'chirishda xatolik.");
}
