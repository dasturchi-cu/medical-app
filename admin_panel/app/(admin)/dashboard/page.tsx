"use client";

import { useEffect, useMemo, useState } from "react";
import { PageSkeleton } from "@/components/page-skeleton";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useAdminStore } from "@/lib/admin-store";

export default function DashboardPage() {
  const { courses, lessons, banners, users, userCourses, userActivity } = useAdminStore((state) => state);
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
    const totalViews = courses.reduce((sum, course) => sum + course.views, 0);
    const totalSales = userCourses.filter((item) => item.is_active).length;
    const conversion = totalViews > 0 ? (totalSales / totalViews) * 100 : 0;

    const now = new Date();
    const nowTime = now.getTime();
    const sevenDaysAgo = nowTime - 7 * 24 * 60 * 60 * 1000;
    const activeUsersIn7Days = users.filter((user) => {
      const time = Date.parse(user.last_active_at.replace(" ", "T"));
      return Number.isFinite(time) && time >= sevenDaysAgo;
    }).length;
    const retention = users.length > 0 ? (activeUsersIn7Days / users.length) * 100 : 0;

    const dailySales = Array.from({ length: 7 }).map((_, offset) => {
      const date = new Date(nowTime - (6 - offset) * 24 * 60 * 60 * 1000);
      const iso = date.toISOString().slice(0, 10);
      const count = userCourses.filter(
        (entry) => entry.is_active && entry.purchased_at && entry.purchased_at.slice(0, 10) === iso,
      ).length;
      return { label: iso.slice(5), value: count };
    });
    const maxDailySales = Math.max(...dailySales.map((point) => point.value), 1);

    return { mostViewed, mostSold, unsold, maxActivity, conversion, retention, dailySales, maxDailySales };
  }, [courses, userActivity, userCourses, users]);

  const stats = [
    { label: "Jami kurslar", value: courses.length },
    { label: "Jami darslar", value: lessons.length },
    { label: "Faol bannerlar", value: banners.length },
    { label: "Faol foydalanuvchilar", value: users.length },
  ];

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {stats.map((stat) => (
          <Card key={stat.label} className="surface-card">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-slate-500">{stat.label}</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold text-slate-900 sm:text-3xl">{stat.value}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Eng ko&apos;p ko&apos;rilgan kurs</CardTitle>
          </CardHeader>
          <CardContent className="text-sm">
            <p className="font-semibold text-slate-900">{analytics.mostViewed?.title_uz ?? "Ma&apos;lumot yo&apos;q"}</p>
            <p className="mt-1 text-slate-500">{analytics.mostViewed?.views ?? 0} marta ko&apos;rilgan</p>
          </CardContent>
        </Card>

        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Eng ko&apos;p sotilgan kurs</CardTitle>
          </CardHeader>
          <CardContent className="text-sm">
            <p className="font-semibold text-slate-900">{analytics.mostSold?.title_uz ?? "Ma&apos;lumot yo&apos;q"}</p>
            <p className="mt-1 text-slate-500">{analytics.mostSold?.sales ?? 0} ta sotuv</p>
          </CardContent>
        </Card>

        <Card className="surface-card">
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

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Conversion</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-slate-900">{analytics.conversion.toFixed(2)}%</p>
            <p className="mt-1 text-xs text-slate-500">
              Kurs ko&apos;rganlardan nechtasi sotib olganini foizda ko&apos;rsatadi. Past bo&apos;lsa, sotuv past degani.
            </p>
          </CardContent>
        </Card>
        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Retention (7 kun)</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-slate-900">{analytics.retention.toFixed(1)}%</p>
            <p className="mt-1 text-xs text-slate-500">
              Oxirgi 7 kunda faol bo&apos;lgan userlar ulushi. 100% bo&apos;lsa, hozircha hamma user faol deb chiqgan.
            </p>
          </CardContent>
        </Card>
        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Top kurs</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-base font-semibold text-slate-900">{analytics.mostSold?.title_uz ?? "Ma&apos;lumot yo&apos;q"}</p>
            <p className="text-sm text-slate-500">{analytics.mostSold?.sales ?? 0} ta sotuv</p>
          </CardContent>
        </Card>
        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Kunlik sotuv (bugun)</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-slate-900">{analytics.dailySales[6]?.value ?? 0}</p>
          </CardContent>
        </Card>
      </div>

      <Card className="surface-card">
        <CardHeader>
          <CardTitle>Kunlik sotuv trendi (7 kun)</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto pb-1">
            <div className="grid min-w-[430px] grid-cols-7 gap-2 sm:gap-3">
              {analytics.dailySales.map((point) => (
                <div key={point.label} className="flex flex-col items-center gap-2">
                  <div className="flex h-28 w-full items-end rounded-xl bg-slate-50 p-2 sm:h-32">
                    <div
                      className="w-full rounded-lg bg-emerald-500 transition-all"
                      style={{ height: `${Math.max(8, (point.value / analytics.maxDailySales) * 100)}%` }}
                    />
                  </div>
                  <span className="text-xs text-slate-500">{point.label}</span>
                  <span className="text-xs font-medium text-slate-700">{point.value}</span>
                </div>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      <Card className="surface-card">
        <CardHeader>
          <CardTitle>Foydalanuvchi faolligi (7 kun)</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto pb-1">
            <div className="grid min-w-[430px] grid-cols-7 gap-2 sm:gap-3">
              {userActivity.map((point) => (
                <div key={point.label} className="flex flex-col items-center gap-2">
                  <div className="flex h-32 w-full items-end rounded-xl bg-slate-50 p-2 sm:h-36">
                    <div
                      className="w-full rounded-lg bg-primary transition-all"
                      style={{ height: `${(point.value / analytics.maxActivity) * 100}%` }}
                    />
                  </div>
                  <span className="text-xs text-slate-500">{point.label}</span>
                </div>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>
    </section>
  );
}
