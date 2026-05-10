"use client";

import { usePathname, useRouter } from "next/navigation";
import { Menu } from "lucide-react";
import { Button } from "@/components/ui/button";
import { setAdminAuthenticated } from "@/lib/admin-auth";

const titleByPath: Record<string, string> = {
  "/dashboard": "Boshqaruv paneli",
  "/courses": "Kurslar",
  "/lessons": "Darslar",
  "/users": "Foydalanuvchilar",
  "/comments": "Izohlar",
  "/ratings": "Baholar",
  "/purchases": "Xaridlar",
  "/home-banners": "Bosh sahifa slaydi",
  "/ads": "Reklamalar",
  "/notifications": "Bildirishnomalar",
  "/tests": "Testlar",
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
    <header className="surface-card sticky top-2 z-30 mb-4 flex flex-wrap items-start justify-between gap-3 p-3 backdrop-blur sm:top-3 sm:mb-6 sm:px-6 sm:py-4">
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
        <h1 className="truncate text-lg font-semibold text-slate-900 sm:text-2xl">{title}</h1>
        <p className="text-xs text-slate-500 sm:text-sm">Barcha kontentni bitta joydan boshqaring.</p>
      </div>
      <div className="flex w-full items-center justify-end gap-2 sm:w-auto">
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
