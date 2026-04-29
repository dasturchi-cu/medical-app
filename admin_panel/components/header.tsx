"use client";

import { usePathname, useRouter } from "next/navigation";
import { Menu } from "lucide-react";
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

interface HeaderProps {
  onOpenMobileMenu?: () => void;
}

export function Header({ onOpenMobileMenu }: HeaderProps) {
  const router = useRouter();
  const pathname = usePathname();
  const title = pathname.startsWith("/users/")
    ? "Foydalanuvchi profili"
    : pathname.startsWith("/courses/")
      ? "Kurs analitikasi"
      : titleByPath[pathname] ?? "Boshqaruv paneli";

  return (
    <header className="surface-card mb-4 flex items-start justify-between gap-3 p-4 sm:mb-6 sm:px-6 sm:py-4">
      <div className="min-w-0">
        <div className="mb-2 flex items-center gap-2 lg:hidden">
          <button
            type="button"
            className="inline-flex size-9 items-center justify-center rounded-xl border border-slate-200"
            onClick={onOpenMobileMenu}
          >
            <Menu className="size-4 text-slate-600" />
          </button>
          <span className="text-xs font-semibold uppercase text-slate-500">Menyu</span>
        </div>
        <h1 className="truncate text-xl font-semibold text-slate-900 sm:text-2xl">{title}</h1>
        <p className="text-xs text-slate-500 sm:text-sm">Barcha kontentni bitta joydan boshqaring.</p>
      </div>
      <div className="flex shrink-0 items-center gap-2">
        <span className="hidden rounded-xl bg-[#eff4ff] px-3 py-2 text-xs font-semibold uppercase tracking-wide text-primary sm:inline-flex">
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
