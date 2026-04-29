import { getApiConfig } from "@/lib/api/config";

export interface TestItem {
  id: string;
  title: string;
  description: string;
  course_id: string | null;
  section_id: string | null;
  lesson_id: string | null;
  estimated_minutes: number;
  is_active: boolean;
  question_count: number;
  created_at: string;
}

export interface TestQuestionItem {
  id: string;
  quiz_id: string;
  question_text: string;
  option_a: string;
  option_b: string;
  option_c: string;
  option_d: string;
  correct_option: string;
  order_no: number;
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

export async function fetchTests() {
  const response = await fetch(endpoint("/api/v1/tests"), { cache: "no-store" });
  if (!response.ok) throw new Error("Testlarni olishda xatolik.");
  const data = (await response.json()) as { items: TestItem[] };
  return data.items ?? [];
}

export async function createTest(payload: {
  title: string;
  description: string;
  estimated_minutes: number;
  course_id?: string | null;
  section_id?: string | null;
  lesson_id?: string | null;
}) {
  const response = await fetch(endpoint("/api/v1/tests"), {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error("Test yaratishda xatolik.");
  return (await response.json()) as TestItem;
}

export async function deleteTest(id: string) {
  const response = await fetch(endpoint(`/api/v1/tests/${id}`), {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error("Test o'chirishda xatolik.");
}

export async function fetchTestQuestions(quizId: string) {
  const response = await fetch(endpoint(`/api/v1/tests/${quizId}/questions`), { cache: "no-store" });
  if (!response.ok) throw new Error("Savollarni olishda xatolik.");
  const data = (await response.json()) as { items: TestQuestionItem[] };
  return data.items ?? [];
}

export async function createTestQuestion(
  quizId: string,
  payload: {
    question_text: string;
    option_a: string;
    option_b: string;
    option_c: string;
    option_d: string;
    correct_option: "A" | "B" | "C" | "D";
    order_no: number;
  },
) {
  const response = await fetch(endpoint(`/api/v1/tests/${quizId}/questions`), {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error("Savol qo'shishda xatolik.");
  return (await response.json()) as TestQuestionItem;
}
