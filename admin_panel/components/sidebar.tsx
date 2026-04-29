"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Bell,
  BookOpen,
  FileQuestion,
  House,
  ImageIcon,
  MessageSquareText,
  MonitorPlay,
  PanelsTopLeft,
  PlayCircle,
  ShoppingCart,
  Users,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";

const navItems = [
  { href: "/dashboard", label: "Boshqaruv paneli", icon: House },
  { href: "/courses", label: "Kurslar", icon: BookOpen },
  { href: "/lessons", label: "Darslar", icon: PlayCircle },
  { href: "/banners", label: "Reklamalar", icon: ImageIcon },
  { href: "/home-banners", label: "Home reklamalari", icon: MonitorPlay },
  { href: "/slides", label: "Slaydlar", icon: PanelsTopLeft },
  { href: "/subscriptions", label: "Kurs obunalari", icon: ShoppingCart },
  { href: "/notifications", label: "Notification", icon: Bell },
  { href: "/tests", label: "Testlar", icon: FileQuestion },
  { href: "/users", label: "Foydalanuvchilar", icon: Users },
  { href: "/comments", label: "Izohlar", icon: MessageSquareText },
];

interface SidebarProps {
  mobileOpen?: boolean;
  onCloseMobile?: () => void;
}

export function Sidebar({ mobileOpen = false, onCloseMobile }: SidebarProps) {
  const pathname = usePathname();

  return (
    <>
      <aside className="surface-card sticky top-4 hidden h-[calc(100vh-2rem)] w-64 shrink-0 p-4 lg:flex lg:flex-col">
        <SidebarContent pathname={pathname} />
      </aside>

      {mobileOpen ? (
        <div className="fixed inset-0 z-40 bg-slate-900/35 lg:hidden" onClick={onCloseMobile}>
          <aside
            className="surface-card h-full w-[90%] max-w-xs overflow-y-auto rounded-none p-4"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="mb-4 flex items-center justify-between">
              <p className="text-sm font-semibold text-slate-700">Menyu</p>
              <button
                type="button"
                className="inline-flex size-9 items-center justify-center rounded-xl border border-slate-200"
                onClick={onCloseMobile}
              >
                <X className="size-4 text-slate-600" />
              </button>
            </div>
            <SidebarContent pathname={pathname} onNavigate={onCloseMobile} />
          </aside>
        </div>
      ) : null}
    </>
  );
}

interface SidebarContentProps {
  pathname: string;
  onNavigate?: () => void;
}

function SidebarContent({ pathname, onNavigate }: SidebarContentProps) {
  return (
    <>
      <div className="mb-8 border-b border-slate-100 pb-4">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">
          Ta&apos;lim Platformasi
        </p>
        <h2 className="mt-2 text-xl font-semibold text-slate-900">Boshqaruv paneli</h2>
      </div>

      <nav className="space-y-1">
        {navItems.map((item) => {
          const isActive = pathname === item.href || pathname.startsWith(`${item.href}/`);

          return (
            <Link
              key={item.href}
              href={item.href}
              onClick={onNavigate}
              className={cn(
                "flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-medium transition-all",
                isActive
                  ? "bg-primary text-primary-foreground shadow-[0_10px_20px_rgba(47,107,255,0.25)]"
                  : "text-slate-600 hover:bg-slate-50 hover:text-slate-900",
              )}
            >
              <item.icon className="size-4" />
              {item.label}
            </Link>
          );
        })}
      </nav>
    </>
  );
}
