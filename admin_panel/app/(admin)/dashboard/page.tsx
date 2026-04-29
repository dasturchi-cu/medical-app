"use client";

import { useEffect, useMemo, useState } from "react";
import { PageSkeleton } from "@/components/page-skeleton";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useAdminStore } from "@/lib/admin-store";

export default function DashboardPage() {
  const { courses, lessons, banners, users, userActivity } = useAdminStore((state) => state);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const analytics = useMemo(() => {
    const mostViewed = [...courses].sort((a, b) => b.views - a.views)[0];
    const mostSold = [...courses].sort((a, b) => b.sales - a.sales)[0];
    const unsold = courses.filter((course) => course.sales === 0);
    const maxActivity = Math.max(...userActivity.map((point) => point.value), 1);

    return { mostViewed, mostSold, unsold, maxActivity };
  }, [courses, userActivity]);

  const stats = [
    { label: "Jami kurslar", value: courses.length },
    { label: "Jami darslar", value: lessons.length },
    { label: "Faol bannerlar", value: banners.length },
    { label: "Faol foydalanuvchilar", value: users.length },
  ];

  if (loading) return <PageSkeleton />;

  return (
    <section className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {stats.map((stat) => (
          <Card key={stat.label} className="surface-card border-slate-100">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-slate-500">{stat.label}</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-semibold text-slate-900">{stat.value}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="surface-card border-slate-100">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Eng ko&apos;p ko&apos;rilgan kurs</CardTitle>
          </CardHeader>
          <CardContent className="text-sm">
            <p className="font-semibold text-slate-900">{analytics.mostViewed?.title_uz ?? "Ma&apos;lumot yo&apos;q"}</p>
            <p className="mt-1 text-slate-500">{analytics.mostViewed?.views ?? 0} marta ko&apos;rilgan</p>
          </CardContent>
        </Card>

        <Card className="surface-card border-slate-100">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Eng ko&apos;p sotilgan kurs</CardTitle>
          </CardHeader>
          <CardContent className="text-sm">
            <p className="font-semibold text-slate-900">{analytics.mostSold?.title_uz ?? "Ma&apos;lumot yo&apos;q"}</p>
            <p className="mt-1 text-slate-500">{analytics.mostSold?.sales ?? 0} ta sotuv</p>
          </CardContent>
        </Card>

        <Card className="surface-card border-slate-100">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Umuman sotilmagan kurslar</CardTitle>
          </CardHeader>
          <CardContent className="text-sm">
            {analytics.unsold.length > 0 ? (
              <ul className="space-y-1">
                {analytics.unsold.map((course) => (
                  <li key={course.id} className="text-slate-700">
                    {course.title_uz}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-slate-500">Barcha kurslarda sotuv mavjud.</p>
            )}
          </CardContent>
        </Card>
      </div>

      <Card className="surface-card border-slate-100">
        <CardHeader>
          <CardTitle>Foydalanuvchi faolligi (7 kun)</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-7 gap-3">
            {userActivity.map((point) => (
              <div key={point.label} className="flex flex-col items-center gap-2">
                <div className="flex h-36 w-full items-end rounded-xl bg-slate-50 p-2">
                  <div
                    className="w-full rounded-lg bg-primary transition-all"
                    style={{ height: `${(point.value / analytics.maxActivity) * 100}%` }}
                  />
                </div>
                <span className="text-xs text-slate-500">{point.label}</span>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </section>
  );
}
