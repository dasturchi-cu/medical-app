"use client";

interface LessonItem {
  id: string;
  title: string;
  order: number;
  isFree: boolean;
}

interface LessonPreviewProps {
  courseTitle: string;
  lessons: LessonItem[];
  draftLessonTitle: string;
  draftOrder: number;
  draftIsFree: boolean;
}

export function LessonPreview({
  courseTitle,
  lessons,
  draftLessonTitle,
  draftOrder,
  draftIsFree,
}: LessonPreviewProps) {
  const draftTitle = draftLessonTitle.trim() || "Yangi dars";
  const list = [
    ...lessons,
    {
      id: "draft",
      title: draftTitle,
      order: Number.isFinite(draftOrder) ? draftOrder : lessons.length + 1,
      isFree: draftIsFree,
    },
  ].sort((a, b) => a.order - b.order);

  return (
    <div className="space-y-3">
      <section className="rounded-2xl border border-slate-100 p-3">
        <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Lesson Preview</p>
        <p className="mt-1 text-sm font-semibold text-slate-900">{courseTitle || "Kurs tanlanmagan"}</p>
      </section>

      <section className="space-y-2">
        {list.slice(0, 8).map((lesson) => (
          <div key={lesson.id} className="flex items-center justify-between rounded-xl border border-slate-100 px-3 py-2">
            <div className="min-w-0">
              <p className="truncate text-sm font-medium text-slate-800">
                {lesson.order}. {lesson.title}
              </p>
              <p className="text-xs text-slate-500">{lesson.isFree ? "Ochiq" : "Qulflangan"}</p>
            </div>
            <span
              className={`rounded-lg px-2 py-1 text-xs ${
                lesson.isFree ? "bg-emerald-50 text-emerald-600" : "bg-slate-100 text-slate-500"
              }`}
            >
              {lesson.isFree ? "Unlock" : "Lock"}
            </span>
          </div>
        ))}
      </section>
    </div>
  );
}
