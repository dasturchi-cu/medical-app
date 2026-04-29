"use client";

import { useEffect, useMemo, useState } from "react";
import { fetchSubscriptionsOverview, type CourseSubscriptionItem } from "@/lib/api/subscriptions";
import { notifyError } from "@/lib/notify";

export default function SubscriptionsPage() {
  const [loading, setLoading] = useState(true);
  const [items, setItems] = useState<CourseSubscriptionItem[]>([]);
  const [totalCourseSales, setTotalCourseSales] = useState(0);
  const [totalUniqueBuyers, setTotalUniqueBuyers] = useState(0);
  const [selectedCourse, setSelectedCourse] = useState("");

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const overview = await fetchSubscriptionsOverview();
        if (!mounted) return;
        setItems(overview.items ?? []);
        setTotalCourseSales(Number(overview.total_course_sales) || 0);
        setTotalUniqueBuyers(Number(overview.total_unique_buyers) || 0);
        setSelectedCourse((overview.items?.[0]?.course_id ?? ""));
      } catch (error) {
        if (!mounted) return;
        notifyError(error instanceof Error ? error.message : "Obunalarni olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    return () => {
      mounted = false;
    };
  }, []);

  const selectedCourseEntry = useMemo(
    () => items.find((course) => course.course_id === selectedCourse),
    [items, selectedCourse],
  );
  const selectedCourseBuyers = selectedCourseEntry?.buyers ?? [];

  if (loading) {
    return <section className="admin-page"><p className="text-sm text-slate-500">Yuklanmoqda...</p></section>;
  }

  return (
    <section className="admin-page">
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="surface-card p-4">
          <p className="text-sm text-slate-500">Jami kurs obunalari</p>
          <p className="mt-2 text-3xl font-semibold text-slate-900">{totalCourseSales}</p>
        </div>
        <div className="surface-card p-4">
          <p className="text-sm text-slate-500">Jami sotib olgan foydalanuvchilar</p>
          <p className="mt-2 text-3xl font-semibold text-slate-900">{totalUniqueBuyers}</p>
        </div>
      </div>

      <div className="surface-card space-y-4 p-4 sm:p-5">
        <div>
          <h3 className="text-base font-semibold text-slate-900">Kurs bo&apos;yicha sotib olganlar</h3>
          <p className="text-sm text-slate-500">Kurs tanlang va aynan shu kurs uchun obuna olganlar ro&apos;yxatini ko&apos;ring.</p>
        </div>

        <div className="grid gap-2">
          <label className="text-sm font-medium text-slate-700">Kursni tanlang</label>
          <select
            value={selectedCourse}
            onChange={(event) => setSelectedCourse(event.target.value)}
            className="h-11 w-full rounded-xl border border-slate-200 px-3 text-sm outline-none focus:border-primary"
          >
            {items.map((course) => (
              <option key={course.course_id} value={course.course_id}>
                {course.course_title}
              </option>
            ))}
          </select>
        </div>

        <div className="rounded-xl bg-slate-50 p-3 text-sm text-slate-700">
          {selectedCourseEntry ? (
            <span>
              <strong>{selectedCourseEntry.course_title}</strong> kursi uchun <strong>{selectedCourseBuyers.length}</strong> ta foydalanuvchi obuna olgan.
            </span>
          ) : (
            <span>Kurs tanlanmagan.</span>
          )}
        </div>

        <div className="space-y-2">
          {selectedCourseBuyers.length > 0 ? (
            selectedCourseBuyers.map((buyer) => (
              <article key={`${buyer.user_id}-${selectedCourseEntry?.course_id}`} className="rounded-xl border border-slate-100 bg-white p-3">
                <p className="font-medium text-slate-800">{buyer.user_name}</p>
                <p className="text-sm text-slate-500">{buyer.user_email}</p>
                <p className="mt-1 text-xs text-slate-500">
                  Sotib olgan sana: {buyer.purchased_at || "Qo&apos;lda ochilgan"}
                </p>
              </article>
            ))
          ) : (
            <p className="text-sm text-slate-400">Bu kurs uchun hozircha obuna olganlar yo&apos;q.</p>
          )}
        </div>
      </div>
    </section>
  );
}
