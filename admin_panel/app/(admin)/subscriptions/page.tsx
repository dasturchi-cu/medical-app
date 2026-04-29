"use client";

import { useMemo, useState } from "react";
import { useAdminStore } from "@/lib/admin-store";

export default function SubscriptionsPage() {
  const { courses, users, userCourses } = useAdminStore((state) => state);
  const [selectedCourse, setSelectedCourse] = useState(courses[0]?.id ?? "");

  const activeRelations = useMemo(
    () => userCourses.filter((item) => item.is_active),
    [userCourses],
  );
  const totalUniqueBuyers = useMemo(
    () => new Set(activeRelations.map((item) => item.user_id)).size,
    [activeRelations],
  );
  const totalCourseSales = activeRelations.length;

  const selectedCourseEntry = courses.find((course) => course.id === selectedCourse);
  const selectedCourseBuyers = useMemo(
    () =>
      activeRelations
        .filter((item) => item.course_id === selectedCourse)
        .map((relation) => ({
          relation,
          user: users.find((user) => user.id === relation.user_id),
        }))
        .filter(
          (entry): entry is { relation: (typeof activeRelations)[number]; user: (typeof users)[number] } =>
            Boolean(entry.user),
        ),
    [activeRelations, selectedCourse, users],
  );

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
            {courses.map((course) => (
              <option key={course.id} value={course.id}>
                {course.title_uz}
              </option>
            ))}
          </select>
        </div>

        <div className="rounded-xl bg-slate-50 p-3 text-sm text-slate-700">
          {selectedCourseEntry ? (
            <span>
              <strong>{selectedCourseEntry.title_uz}</strong> kursi uchun <strong>{selectedCourseBuyers.length}</strong> ta foydalanuvchi obuna olgan.
            </span>
          ) : (
            <span>Kurs tanlanmagan.</span>
          )}
        </div>

        <div className="space-y-2">
          {selectedCourseBuyers.length > 0 ? (
            selectedCourseBuyers.map(({ relation, user }) => (
              <article key={`${user.id}-${relation.course_id}`} className="rounded-xl border border-slate-100 bg-white p-3">
                <p className="font-medium text-slate-800">{user.name}</p>
                <p className="text-sm text-slate-500">{user.email}</p>
                <p className="mt-1 text-xs text-slate-500">
                  Sotib olgan sana: {relation.purchased_at || "Qo&apos;lda ochilgan"}
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
