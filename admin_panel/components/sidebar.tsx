"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { BookOpen, House, ImageIcon, MessageSquareText, PlayCircle, Users } from "lucide-react";
import { cn } from "@/lib/utils";

const navItems = [
  { href: "/dashboard", label: "Boshqaruv paneli", icon: House },
  { href: "/courses", label: "Kurslar", icon: BookOpen },
  { href: "/lessons", label: "Darslar", icon: PlayCircle },
  { href: "/banners", label: "Bannerlar", icon: ImageIcon },
  { href: "/users", label: "Foydalanuvchilar", icon: Users },
  { href: "/comments", label: "Izohlar", icon: MessageSquareText },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="surface-card sticky top-6 flex h-[calc(100vh-3rem)] w-64 shrink-0 flex-col p-4">
      <SidebarContent pathname={pathname} />
    </aside>
  );
}

interface SidebarContentProps {
  pathname: string;
}

function SidebarContent({ pathname }: SidebarContentProps) {
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
              className={cn(
                "flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-medium transition-colors",
                isActive
                  ? "bg-primary text-primary-foreground shadow-sm"
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
