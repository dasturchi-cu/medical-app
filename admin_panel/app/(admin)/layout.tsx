"use client";

import type { ReactNode } from "react";
import { AuthGuard } from "@/components/auth-guard";
import { Header } from "@/components/header";
import { Sidebar } from "@/components/sidebar";

interface AdminLayoutProps {
  children: ReactNode;
}

export default function AdminLayout({ children }: AdminLayoutProps) {
  return (
    <AuthGuard>
      <div className="w-full overflow-x-auto">
        <div className="mx-auto flex min-h-screen min-w-[1200px] max-w-[1440px] gap-6 p-6">
          <Sidebar />
          <main className="min-h-[calc(100vh-3rem)] min-w-0 flex-1">
            <Header />
            {children}
          </main>
        </div>
      </div>
    </AuthGuard>
  );
}
