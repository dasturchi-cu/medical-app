"use client";

import { useEffect, useMemo, useState } from "react";
import { fetchSubscriptionsOverview, type CourseSubscriptionItem } from "@/lib/api/subscriptions";
import { notifyError } from "@/lib/notify";

export default function PurchasesPage() {
  const [loading, setLoading] = useState(true);
  const [items, setItems] = useState<CourseSubscriptionItem[]>([]);
  const [search, setSearch] = useState("");

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const overview = await fetchSubscriptionsOverview();
        if (!mounted) return;
        setItems(overview.items ?? []);
      } catch (error) {
        if (!mounted) return;
        notifyError(error instanceof Error ? error.message : "Sotuvlarni olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    return () => {
      mounted = false;
    };
  }, []);

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.flatMap((course) =>
      course.buyers
        .filter((buyer) => !q || `${course.course_title} ${buyer.user_name} ${buyer.user_email}`.toLowerCase().includes(q))
        .map((buyer) => ({
          id: `${course.course_id}-${buyer.user_id}-${buyer.purchased_at}`,
          course: course.course_title,
          user: buyer.user_name,
          email: buyer.user_email,
          date: buyer.purchased_at || "manual",
        })),
    );
  }, [items, search]);

  return (
    <section className="admin-page space-y-4">
      <div className="surface-card p-4">
        <label htmlFor="purchase-search" className="mb-2 block text-sm font-medium text-slate-700">
          Xaridlarni qidirish
        </label>
        <input
          id="purchase-search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          className="h-11 w-full rounded-xl border border-slate-200 px-3 text-sm outline-none focus:border-primary"
          placeholder="Kurs, foydalanuvchi yoki email bo'yicha qidiring"
        />
      </div>

      <div className="surface-card overflow-hidden">
        <div className="grid grid-cols-1 gap-px bg-slate-100 sm:grid-cols-4">
          <div className="bg-slate-50 p-3 text-xs font-semibold uppercase tracking-wide text-slate-500">Kurs</div>
          <div className="bg-slate-50 p-3 text-xs font-semibold uppercase tracking-wide text-slate-500">Foydalanuvchi</div>
          <div className="bg-slate-50 p-3 text-xs font-semibold uppercase tracking-wide text-slate-500">Email</div>
          <div className="bg-slate-50 p-3 text-xs font-semibold uppercase tracking-wide text-slate-500">Purchased At</div>
        </div>
        {loading ? (
          <p className="p-4 text-sm text-slate-500">Yuklanmoqda...</p>
        ) : rows.length === 0 ? (
          <p className="p-4 text-sm text-slate-500">Sotuv yozuvlari topilmadi.</p>
        ) : (
          rows.map((row) => (
            <div key={row.id} className="grid grid-cols-1 gap-px border-t border-slate-100 sm:grid-cols-4">
              <div className="p-3 text-sm text-slate-700">{row.course}</div>
              <div className="p-3 text-sm text-slate-700">{row.user}</div>
              <div className="p-3 text-sm text-slate-700">{row.email}</div>
              <div className="p-3 text-sm text-slate-500">{row.date}</div>
            </div>
          ))
        )}
      </div>
    </section>
  );
}
