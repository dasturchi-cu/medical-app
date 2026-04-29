 "use client";

import { useEffect, useMemo, useState } from "react";
import { useParams } from "next/navigation";
import { PageSkeleton } from "@/components/page-skeleton";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { blockUser, fetchUserEntitlements, fetchUsers, grantCourse, revokeCourse, type AdminUserItem, type UserEntitlementItem, unblockUser } from "@/lib/api/users";
import { fetchCourses } from "@/lib/api/courses";
import { notifyError, notifySuccess } from "@/lib/notify";

export default function UserDetailPage() {
  const params = useParams<{ id: string }>();
  const userId = params.id;
  const [loading, setLoading] = useState(true);
  const [users, setUsers] = useState<AdminUserItem[]>([]);
  const [courses, setCourses] = useState<Array<{ id: string; title_uz: string }>>([]);
  const [entitlements, setEntitlements] = useState<UserEntitlementItem[]>([]);
  const [selectedCourse, setSelectedCourse] = useState("");

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const [userItems, courseItems, entitlementItems] = await Promise.all([
          fetchUsers(),
          fetchCourses(),
          fetchUserEntitlements(userId),
        ]);
        if (!mounted) return;
        setUsers(userItems);
        setCourses(courseItems.map((item) => ({ id: item.id, title_uz: item.title_uz })));
        setEntitlements(entitlementItems);
        setSelectedCourse(courseItems[0]?.id ?? "");
      } catch (error) {
        if (!mounted) return;
        notifyError(error instanceof Error ? error.message : "Foydalanuvchi ma'lumotlarini olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    return () => {
      mounted = false;
    };
  }, [userId]);

  const user = useMemo(() => users.find((item) => item.id === userId), [users, userId]);
  const activeEntitlements = useMemo(() => entitlements.filter((item) => item.is_active), [entitlements]);
  const selectedCourseData = useMemo(
    () => courses.find((course) => course.id === selectedCourse),
    [courses, selectedCourse],
  );
  const courseTitleById = useMemo(
    () => new Map(courses.map((course) => [course.id, course.title_uz])),
    [courses],
  );

  if (loading) return <PageSkeleton />;

  if (!user) {
    return <div className="surface-card p-6 text-sm text-slate-500">Foydalanuvchi topilmadi.</div>;
  }

  return (
    <section className="admin-page">
      <div className="surface-card p-5">
        <h2 className="text-xl font-semibold text-slate-900">{user.name}</h2>
        <p className="mt-1 text-sm text-slate-500">{user.email || "-"}</p>
        <p className="mt-2 text-xs text-slate-500">Ro&apos;yxatdan o&apos;tgan: {user.registration_date || "-"}</p>
        <p className="mt-1 text-xs text-slate-500">User ID: {user.id}</p>
        <div className="mt-4 flex flex-wrap gap-2">
          <Button
            variant="destructive"
            disabled={user.is_blocked}
            onClick={async () => {
              try {
                await blockUser(user.id);
                setUsers((prev) => prev.map((item) => (item.id === user.id ? { ...item, is_blocked: true } : item)));
                notifySuccess("Foydalanuvchi bloklandi.");
              } catch (error) {
                notifyError(error instanceof Error ? error.message : "Bloklashda xatolik.");
              }
            }}
          >
            Block user
          </Button>
          <Button
            variant="outline"
            disabled={!user.is_blocked}
            onClick={async () => {
              try {
                await unblockUser(user.id);
                setUsers((prev) => prev.map((item) => (item.id === user.id ? { ...item, is_blocked: false } : item)));
                notifySuccess("Foydalanuvchi blokdan chiqarildi.");
              } catch (error) {
                notifyError(error instanceof Error ? error.message : "Unblockda xatolik.");
              }
            }}
          >
            Unblock user
          </Button>
        </div>
      </div>

      <div className="surface-card p-5">
        <h3 className="text-base font-semibold text-slate-900">Kurs berish</h3>
        <div className="mt-3 flex flex-col gap-2 sm:flex-row">
          <Select value={selectedCourse} onValueChange={(value) => setSelectedCourse(value ?? "")}>
            <SelectTrigger className="h-10 rounded-xl border-slate-200 sm:max-w-sm">
              <SelectValue placeholder="Kursni tanlang">
                {selectedCourseData?.title_uz ?? "Kursni tanlang"}
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              {courses.map((course) => (
                <SelectItem key={course.id} value={course.id}>
                  {course.title_uz}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button
            className="h-10 rounded-xl"
            onClick={async () => {
              if (!selectedCourse) {
                notifyError("Avval kurs tanlang.");
                return;
              }
              try {
                await grantCourse(user.id, selectedCourse);
                const nextEntitlements = await fetchUserEntitlements(user.id);
                setEntitlements(nextEntitlements);
                notifySuccess("Foydalanuvchiga kurs berildi.");
              } catch (error) {
                notifyError(error instanceof Error ? error.message : "Kurs berishda xatolik.");
              }
            }}
          >
            Kurs berish
          </Button>
        </div>
      </div>

      <div className="surface-card p-5">
        <h3 className="text-base font-semibold text-slate-900">Faol kurslar</h3>
        <div className="mt-3 space-y-2">
          {activeEntitlements.length > 0 ? (
            activeEntitlements.map((item) => (
              <div key={item.id} className="flex flex-col gap-2 rounded-xl bg-slate-50 p-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <p className="text-sm font-medium text-slate-900">
                    {courseTitleById.get(item.course_id) || item.course_title || item.course_id}
                  </p>
                  <p className="text-xs text-slate-500">{item.purchased_at ? item.purchased_at.slice(0, 16).replace("T", " ") : "Qo'lda berilgan"}</p>
                </div>
                <Button
                  variant="destructive"
                  className="h-8 rounded-lg px-3 text-xs"
                  onClick={async () => {
                    try {
                      await revokeCourse(user.id, item.course_id);
                      const nextEntitlements = await fetchUserEntitlements(user.id);
                      setEntitlements(nextEntitlements);
                      notifySuccess("Kurs foydalanuvchidan olindi.");
                    } catch (error) {
                      notifyError(error instanceof Error ? error.message : "Kursni olib tashlashda xatolik.");
                    }
                  }}
                >
                  Olib tashlash
                </Button>
              </div>
            ))
          ) : (
            <p className="text-sm text-slate-500">Faol kurslar yo&apos;q.</p>
          )}
        </div>
      </div>
    </section>
  );
}
