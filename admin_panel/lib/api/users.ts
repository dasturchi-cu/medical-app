import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface AdminUserItem {
  id: string;
  name: string;
  email: string;
  registration_date: string;
  login_count: number;
  app_open_count: number;
  is_blocked: boolean;
}

export interface UserEntitlementItem {
  id: string;
  course_id: string;
  course_title: string;
  purchased_at: string;
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
    const body = (await response.json()) as { detail?: string };
    return body.detail?.trim() || fallback;
  } catch {
    return fallback;
  }
}

export async function fetchUsers() {
  const response = await apiFetch("/api/v1/admin/users", {
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Foydalanuvchilarni olishda xatolik."));
  const data = (await response.json()) as { items: AdminUserItem[] };
  return data.items ?? [];
}

export async function blockUser(userId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}/block`, {
    method: "POST",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Foydalanuvchini bloklashda xatolik."));
}

export async function unblockUser(userId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}/unblock`, {
    method: "POST",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Foydalanuvchini blokdan chiqarishda xatolik."));
}

export async function grantCourse(userId: string, courseId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}/grant-course`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ course_id: courseId }),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kurs berishda xatolik."));
}

export async function fetchUserEntitlements(userId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}/entitlements`, {
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kurs ruxsatlarini olishda xatolik."));
  const data = (await response.json()) as { items: UserEntitlementItem[] };
  return data.items ?? [];
}

export async function revokeCourse(userId: string, courseId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}/revoke-course`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ course_id: courseId }),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kursni olib tashlashda xatolik."));
}
