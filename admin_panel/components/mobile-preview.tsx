"use client";

import type { ReactNode } from "react";

interface MobilePreviewProps {
  title?: string;
  subtitle?: string;
  children: ReactNode;
}

export function MobilePreview({
  title = "Mobile Preview",
  subtitle = "Ilova ko'rinishi",
  children,
}: MobilePreviewProps) {
  return (
    <aside className="surface-card w-full p-4">
      <div className="mb-3">
        <p className="text-sm font-semibold text-slate-900">{title}</p>
        <p className="text-xs text-slate-500">{subtitle}</p>
      </div>

      <div className="mx-auto w-full max-w-[360px] rounded-[28px] bg-[#0f172a] p-2 shadow-2xl">
        <div className="relative h-[690px] overflow-hidden rounded-[22px] bg-white">
          <div className="absolute left-1/2 top-2 h-1.5 w-20 -translate-x-1/2 rounded-full bg-slate-200" />
          <div className="h-full overflow-y-auto px-3 pb-4 pt-6">{children}</div>
        </div>
      </div>
    </aside>
  );
}
