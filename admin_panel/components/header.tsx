"use client";

import { usePathname, useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { setAdminAuthenticated } from "@/lib/admin-auth";

const titleByPath: Record<string, string> = {
  "/dashboard": "Boshqaruv paneli",
  "/courses": "Kurslar",
  "/lessons": "Darslar",
  "/banners": "Bannerlar",
  "/users": "Foydalanuvchilar",
  "/comments": "Izohlar va reytinglar",
};

export function Header() {
  const router = useRouter();
  const pathname = usePathname();
  const title = pathname.startsWith("/users/")
    ? "Foydalanuvchi profili"
    : pathname.startsWith("/courses/")
      ? "Kurs analitikasi"
      : titleByPath[pathname] ?? "Boshqaruv paneli";

  return (
    <header className="surface-card mb-6 flex items-center justify-between gap-3 px-6 py-4">
      <div className="min-w-0">
        <h1 className="truncate text-2xl font-semibold text-slate-900">{title}</h1>
        <p className="text-sm text-slate-500">Barcha kontentni bitta joydan boshqaring.</p>
      </div>
      <div className="flex shrink-0 items-center gap-2">
        <span className="inline-flex rounded-xl bg-[#eff4ff] px-3 py-2 text-xs font-semibold uppercase tracking-wide text-primary">
          Administrator
        </span>
        <Button
          variant="outline"
          className="h-9 rounded-xl border-slate-200 px-3 text-xs"
          onClick={() => {
            setAdminAuthenticated(false);
            router.replace("/login");
          }}
        >
          Chiqish
        </Button>
      </div>
    </header>
  );
}
