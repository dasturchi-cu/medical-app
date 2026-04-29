"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { PageSkeleton } from "@/components/page-skeleton";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { adminActions, useAdminStore } from "@/lib/admin-store";
import { notifySuccess } from "@/lib/notify";

export default function UsersPage() {
  const { users, courses } = useAdminStore((state) => state);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [selectedCourse, setSelectedCourse] = useState(courses[0]?.id ?? "");

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const filteredUsers = useMemo(
    () => users.filter((user) => user.id.toLowerCase().includes(query.trim().toLowerCase())),
    [query, users],
  );

  const columns = useMemo(
    () => [
      {
        key: "name",
        label: "Foydalanuvchi",
        render: (user: (typeof filteredUsers)[number]) => (
          <Link href={`/users/${user.id}`} className="text-primary hover:underline">
            {user.name}
          </Link>
        ),
      },
      { key: "id", label: "User ID" },
      { key: "email", label: "Email" },
      { key: "login_count", label: "Login soni" },
      { key: "app_open_count", label: "App open soni" },
      {
        key: "is_blocked",
        label: "Holat",
        render: (user: (typeof filteredUsers)[number]) =>
          user.is_blocked ? (
            <span className="rounded-lg bg-red-50 px-2 py-1 text-xs text-red-600">Blocked</span>
          ) : (
            <span className="rounded-lg bg-emerald-50 px-2 py-1 text-xs text-emerald-600">Active</span>
          ),
      },
      {
        key: "actions",
        label: "Amallar",
        render: (user: (typeof filteredUsers)[number]) => (
          <div className="flex flex-wrap gap-2">
            <Button
              variant="destructive"
              className="h-8 rounded-lg px-3 text-xs"
              onClick={() => {
                adminActions.blockUser(user.id);
                notifySuccess("Foydalanuvchi bloklandi.");
              }}
              disabled={user.is_blocked}
            >
              Block user
            </Button>
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs"
              onClick={() => {
                adminActions.unblockUser(user.id);
                notifySuccess("Foydalanuvchi blokdan chiqarildi.");
              }}
              disabled={!user.is_blocked}
            >
              Unblock user
            </Button>
            <Button
              className="h-8 rounded-lg bg-primary px-3 text-xs text-white"
              onClick={() => {
                adminActions.grantCourse(
                  user.id,
                  selectedCourse,
                  null,
                );
                notifySuccess("Foydalanuvchiga kurs muvaffaqiyatli berildi.");
              }}
            >
              Kurs berish
            </Button>
          </div>
        ),
      },
    ],
    [selectedCourse],
  );

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <div className="space-y-4">
        <div className="surface-card p-4">
          <label htmlFor="search-user" className="mb-2 block text-sm font-medium text-slate-700">
            User ID qidirish
          </label>
          <Input
            id="search-user"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Masalan: user-1"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>

        <div className="surface-card grid gap-3 p-4">
          <div>
            <label className="mb-2 block text-sm font-medium text-slate-700">Qaysi kurs beriladi?</label>
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
        </div>

        <AppTable columns={columns} data={filteredUsers} emptyText="Kiritilgan ID bo&apos;yicha foydalanuvchi topilmadi." />
      </div>
    </section>
  );
}
