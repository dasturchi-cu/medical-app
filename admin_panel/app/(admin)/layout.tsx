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
      <div className="mx-auto flex max-w-[1400px] gap-6 p-4">
        <Sidebar />
        <main className="min-h-[calc(100vh-2rem)] flex-1">
          <Header />
          {children}
        </main>
      </div>
    </AuthGuard>
  );
}
