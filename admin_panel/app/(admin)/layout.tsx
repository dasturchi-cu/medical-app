"use client";

import { useState } from "react";
import type { ReactNode } from "react";
import { AuthGuard } from "@/components/auth-guard";
import { Header } from "@/components/header";
import { Sidebar } from "@/components/sidebar";

interface AdminLayoutProps {
  children: ReactNode;
}

export default function AdminLayout({ children }: AdminLayoutProps) {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <AuthGuard>
      <div className="mx-auto flex w-full max-w-[1440px] gap-4 p-4 md:gap-6 md:p-6">
        <Sidebar mobileOpen={mobileOpen} onCloseMobile={() => setMobileOpen(false)} />
        <main className="min-h-[calc(100vh-2rem)] min-w-0 flex-1">
          <Header onOpenMobileMenu={() => setMobileOpen(true)} />
          {children}
        </main>
      </div>
    </AuthGuard>
  );
}
