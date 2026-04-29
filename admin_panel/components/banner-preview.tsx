"use client";

interface BannerPreviewProps {
  title: string;
  image?: string;
}

export function BannerPreview({ title, image }: BannerPreviewProps) {
  return (
    <div className="space-y-4">
      <section className="rounded-2xl bg-slate-50 p-3">
        <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">Banner Preview</p>
        <div
          className="h-32 rounded-2xl bg-cover bg-center p-3"
          style={
            image?.trim()
              ? { backgroundImage: `url(${image})` }
              : { background: "linear-gradient(135deg, #2F6BFF 0%, #5D8DFF 100%)" }
          }
        >
          <p className="max-w-[80%] text-sm font-semibold text-white">
            {title.trim() || "Sarlavha shu yerda ko'rinadi"}
          </p>
        </div>
      </section>

      <section className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Home List</p>
        <div className="rounded-2xl border border-slate-100 p-3">
          <div className="mb-2 h-14 rounded-xl bg-slate-100" />
          <div className="mb-2 h-14 rounded-xl bg-slate-100" />
          <div className="h-14 rounded-xl bg-slate-100" />
        </div>
      </section>
    </div>
  );
}
