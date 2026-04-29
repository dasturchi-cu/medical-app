import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface CourseBuyerItem {
  user_id: string;
  user_name: string;
  user_email: string;
  purchased_at: string;
}

export interface CourseSubscriptionItem {
  course_id: string;
  course_title: string;
  buyers: CourseBuyerItem[];
}

export interface SubscriptionsOverview {
  total_course_sales: number;
  total_unique_buyers: number;
  items: CourseSubscriptionItem[];
}

function headers() {
  const { adminApiKey } = getApiConfig();
  return {
    "Content-Type": "application/json",
    ...(adminApiKey ? { "x-admin-api-key": adminApiKey } : {}),
  };
}

export async function fetchSubscriptionsOverview() {
  const response = await apiFetch("/api/v1/subscriptions/overview", {
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) {
    throw new Error("Obunalar ma'lumotini olishda xatolik.");
  }
  return (await response.json()) as SubscriptionsOverview;
}
