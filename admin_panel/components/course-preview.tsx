"use client";

interface CoursePreviewProps {
  title: string;
  image?: string;
  videoCount: number;
  sampleCourses: string[];
}

export function CoursePreview({ title, image, videoCount, sampleCourses }: CoursePreviewProps) {
  const courseTitle = title.trim() || "Yangi kurs sarlavhasi";

  return (
    <div className="space-y-4">
      <section className="rounded-2xl bg-slate-50 p-3">
        <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">Home Preview</p>
        <div
          className="h-28 rounded-2xl p-3 text-white"
          style={
            image?.trim()
              ? { backgroundImage: `linear-gradient(rgba(47,107,255,0.32), rgba(47,107,255,0.32)), url(${image})`, backgroundSize: "cover", backgroundPosition: "center" }
              : { background: "linear-gradient(135deg, #2F6BFF 0%, #5D8DFF 100%)" }
          }
        >
          <p className="text-xs text-white/80">Kurs</p>
          <p className="mt-1 line-clamp-2 text-sm font-semibold">{courseTitle}</p>
        </div>
        <div className="mt-3 flex gap-2">
          <span className="rounded-full bg-[#eff4ff] px-3 py-1 text-xs text-primary">Nevralogiya</span>
          <span className="rounded-full bg-slate-100 px-3 py-1 text-xs text-slate-600">Online</span>
        </div>
        <div className="mt-3 space-y-2">
          {sampleCourses.slice(0, 3).map((course) => (
            <div key={course} className="rounded-xl border border-slate-100 px-3 py-2 text-sm text-slate-700">
              {course}
            </div>
          ))}
        </div>
      </section>

      <section className="rounded-2xl border border-slate-100 p-3">
        <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">Course Preview</p>
        <p className="text-base font-semibold text-slate-900">{courseTitle}</p>
        <p className="mt-1 text-xs text-slate-500">{videoCount} ta video</p>
        <button
          type="button"
          className="mt-3 inline-flex h-9 items-center justify-center rounded-xl bg-[#2F6BFF] px-4 text-sm font-medium text-white"
        >
          Boshlash
        </button>
      </section>
    </div>
  );
}
