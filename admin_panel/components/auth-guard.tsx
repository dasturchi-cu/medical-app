"use client";

import { useEffect } from "react";
import type { ReactNode } from "react";
import { usePathname, useRouter } from "next/navigation";
import { isAdminAuthenticated } from "@/lib/admin-auth";

interface AuthGuardProps {
  children: ReactNode;
}

export function AuthGuard({ children }: AuthGuardProps) {
  const router = useRouter();
  const pathname = usePathname();
  const allowed = isAdminAuthenticated();

  useEffect(() => {
    if (!allowed) {
      router.replace(`/login?next=${encodeURIComponent(pathname)}`);
    }
  }, [allowed, pathname, router]);

  if (!allowed) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="surface-card w-full max-w-sm p-6 text-center text-sm text-slate-500">
          Tekshirilmoqda...
        </div>
      </div>
    );
  }

  return <>{children}</>;
}
