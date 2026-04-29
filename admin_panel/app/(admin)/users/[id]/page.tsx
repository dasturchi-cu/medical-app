"use client";

import { useEffect, useMemo, useState } from "react";
import type { ComponentType, ReactNode } from "react";
import { useParams } from "next/navigation";
import {
  Activity,
  Copy,
  MessageCircle,
  MonitorSmartphone,
  ShoppingCart,
  Star,
  TimerReset,
  Video,
} from "lucide-react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { PageSkeleton } from "@/components/page-skeleton";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { adminActions, courseTitleByLanguage, useAdminStore } from "@/lib/admin-store";
import { notifySuccess } from "@/lib/notify";

export default function UserDetailPage() {
  const params = useParams<{ id: string }>();
  const userId = params.id;
  const state = useAdminStore((current) => current);
  const [loading, setLoading] = useState(true);
  const [deleteCommentId, setDeleteCommentId] = useState<string | null>(null);
  const [selectedCourse, setSelectedCourse] = useState(state.courses[0]?.id ?? "");

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const user = useMemo(() => state.users.find((item) => item.id === userId), [state.users, userId]);
  const activity = useMemo(
    () => state.userActivityRows.find((item) => item.user_id === userId),
    [state.userActivityRows, userId],
  );
  const videos = useMemo(
    () => state.videoProgressRows.filter((item) => item.user_id === userId),
    [state.videoProgressRows, userId],
  );
  const sessions = useMemo(
    () => state.pomodoroSessions.filter((item) => item.user_id === userId),
    [state.pomodoroSessions, userId],
  );
  const comments = useMemo(
    () => state.comments.filter((item) => item.user_id === userId),
    [state.comments, userId],
  );
  const ratings = useMemo(
    () => state.ratings.filter((item) => item.user_id === userId),
    [state.ratings, userId],
  );
  const courseRelations = useMemo(
    () => state.userCourses.filter((item) => item.user_id === userId),
    [state.userCourses, userId],
  );

  const purchasedCourses = useMemo(
    () =>
      courseRelations
        .filter((item) => item.is_active)
        .map((relation) => ({
          relation,
          course: state.courses.find((course) => course.id === relation.course_id),
        }))
        .filter((entry): entry is { relation: (typeof courseRelations)[number]; course: (typeof state.courses)[number] } => Boolean(entry.course)),
    [courseRelations, state],
  );

  const notPurchasedCourses = useMemo(
    () =>
      state.courses.filter((course) => {
        const relation = courseRelations.find((item) => item.course_id === course.id);
        return !relation || !relation.is_active;
      }),
    [courseRelations, state.courses],
  );
  const selectedCourseEntry = state.courses.find((course) => course.id === selectedCourse);

  const focusMinutes = sessions.reduce((sum, item) => sum + item.focus_minutes, 0);
  const breakMinutes = sessions.reduce((sum, item) => sum + item.break_minutes, 0);

  if (loading) return <PageSkeleton />;

  if (!user) {
    return (
      <div className="surface-card p-8 text-center text-sm text-slate-500">
        Foydalanuvchi topilmadi.
      </div>
    );
  }

  return (
    <section className="admin-page">
      <div className="surface-card p-4 sm:p-6">
        <h2 className="text-xl font-semibold text-slate-900 sm:text-2xl">{user.name}</h2>
        <p className="mt-1 text-sm text-slate-500">{user.email}</p>
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <span className="rounded-xl bg-slate-100 px-3 py-1 text-xs text-slate-600">{user.id}</span>
          <Button size="sm" variant="outline" className="h-8 rounded-lg border-slate-200" onClick={() => navigator.clipboard.writeText(user.id)}>
            <Copy className="mr-1 size-3.5" />
            Nusxa olish
          </Button>
          <span className="text-xs text-slate-500">Ro&apos;yxatdan o&apos;tgan: {user.registration_date}</span>
        </div>
      </div>

      <SectionCard icon={Activity} title="Faollik">
        <InfoGridItem label="Login soni" value={String(activity?.login_count ?? 0)} />
        <InfoGridItem label="Oxirgi aktivlik" value={activity?.last_active_at ?? "-"} />
        <InfoGridItem label="Jami vaqt" value={`${activity?.total_hours ?? 0} soat`} />
      </SectionCard>

      <SectionCard icon={Video} title="Video faolligi">
        <div className="space-y-2">
          {videos.length > 0 ? (
            videos.map((video) => (
              <div key={video.id} className="rounded-xl bg-slate-50 p-3">
                <p className="font-medium text-slate-800">{video.video_title}</p>
                <p className="text-xs text-slate-500">Ko&apos;rilgan foiz: {video.watched_percent}%</p>
                <p className="text-xs text-slate-500">Oxirgi ko&apos;rilgan: {video.last_watched_at}</p>
              </div>
            ))
          ) : (
            <p className="text-sm text-slate-400">Video faolligi yo&apos;q.</p>
          )}
        </div>
      </SectionCard>

      <SectionCard icon={TimerReset} title="Pomodoro">
        <InfoGridItem label="Jami pomodoro vaqti" value={`${Math.round(focusMinutes / 60)} soat`} />
        <InfoGridItem label="Sessiya soni" value={String(sessions.length)} />
        <InfoGridItem label="Fokus vs tanaffus" value={`${focusMinutes}m / ${breakMinutes}m`} />
      </SectionCard>

      <SectionCard icon={MessageCircle} title="Izohlar">
        <div className="space-y-2">
          {comments.length > 0 ? (
            comments.map((comment) => {
              const course = state.courses.find((item) => item.id === comment.course_id);
              return (
                <div key={comment.id} className="flex items-start justify-between gap-3 rounded-xl bg-slate-50 p-3">
                  <div>
                    <p className="text-sm font-medium text-slate-800">
                      {course ? courseTitleByLanguage(course, "uz") : comment.course_id}
                    </p>
                    <p className="text-sm text-slate-600">{comment.text}</p>
                    <p className="text-xs text-slate-500">{comment.created_at}</p>
                  </div>
                  <Button
                    variant="destructive"
                    className="h-8 rounded-lg px-3 text-xs"
                    onClick={() => setDeleteCommentId(comment.id)}
                  >
                    O&apos;chirish
                  </Button>
                </div>
              );
            })
          ) : (
            <p className="text-sm text-slate-400">Izohlar mavjud emas.</p>
          )}
        </div>
      </SectionCard>

      <SectionCard icon={Star} title="Baholar">
        <div className="space-y-2">
          {ratings.length > 0 ? (
            ratings.map((rating) => {
              const course = state.courses.find((item) => item.id === rating.course_id);
              return (
                <div key={rating.id} className="rounded-xl bg-slate-50 p-3">
                  <p className="text-sm font-medium text-slate-800">
                    {course ? courseTitleByLanguage(course, "uz") : rating.course_id}
                  </p>
                  <p className="text-yellow-500">{"⭐".repeat(rating.rating)}</p>
                </div>
              );
            })
          ) : (
            <p className="text-sm text-slate-400">Baholar mavjud emas.</p>
          )}
        </div>
      </SectionCard>

      <SectionCard icon={ShoppingCart} title="Xaridlar va kurs ruxsati">
        <div className="rounded-xl border border-slate-100 p-3">
          <p className="mb-2 text-sm font-medium text-slate-700">Kurs berish</p>
          <div className="flex flex-col gap-2 sm:flex-row">
            <Select value={selectedCourse} onValueChange={(value) => setSelectedCourse(value ?? "")}>
              <SelectTrigger className="h-10 rounded-xl border-slate-200">
                <SelectValue placeholder="Kursni tanlang">
                  {selectedCourseEntry ? courseTitleByLanguage(selectedCourseEntry, "uz") : "Kursni tanlang"}
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {state.courses.map((course) => (
                  <SelectItem key={course.id} value={course.id}>
                    {courseTitleByLanguage(course, "uz")}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Button
              className="h-10 rounded-xl sm:px-4"
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
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <div className="rounded-xl bg-slate-50 p-3">
            <p className="mb-2 text-sm font-semibold text-slate-700">Sotib olgan / faol kurslar</p>
            <div className="space-y-2">
              {purchasedCourses.length > 0 ? (
                purchasedCourses.map((item) => (
                  <div key={item.course.id} className="flex flex-col gap-2 rounded-lg bg-white px-2 py-2 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <p className="text-sm">{courseTitleByLanguage(item.course, "uz")}</p>
                      <p className="text-xs text-slate-500">
                        Sana: {item.relation.purchased_at || "Qo'lda ochilgan"}
                      </p>
                    </div>
                    <Button
                      variant="destructive"
                      className="h-8 rounded-lg px-3 text-xs"
                      onClick={() => {
                        adminActions.revokeCourse(user.id, item.course.id, null);
                        notifySuccess("Foydalanuvchidan kurs muvaffaqiyatli olib tashlandi.");
                      }}
                    >
                      Olib tashlash
                    </Button>
                  </div>
                ))
              ) : (
                <p className="text-sm text-slate-400">Faol kurslar yo&apos;q.</p>
              )}
            </div>
          </div>

          <div className="rounded-xl bg-slate-50 p-3">
            <p className="mb-2 text-sm font-semibold text-slate-700">Sotib olmagan kurslar</p>
            <div className="space-y-2">
              {notPurchasedCourses.length > 0 ? (
                notPurchasedCourses.map((course) => (
                  <div key={course.id} className="rounded-lg bg-white px-2 py-2 text-sm text-slate-700">
                    {courseTitleByLanguage(course, "uz")}
                  </div>
                ))
              ) : (
                <p className="text-sm text-slate-400">Barcha kurslar ochilgan.</p>
              )}
            </div>
          </div>
        </div>
      </SectionCard>

      <SectionCard icon={MonitorSmartphone} title="Qurilma ma&apos;lumotlari">
        <InfoGridItem label="Login usuli" value={user.login_method} />
        <InfoGridItem label="Qurilma turi" value={user.device_type} />
        <InfoGridItem label="Oxirgi qurilma" value={user.last_device_info} />
      </SectionCard>

      <ConfirmDialog
        open={Boolean(deleteCommentId)}
        title="Izohni o&apos;chirish"
        description="Ushbu izohni o&apos;chirishni tasdiqlaysizmi?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteCommentId(null)}
        onConfirm={() => {
          if (!deleteCommentId) return;
          adminActions.deleteComment(deleteCommentId);
          notifySuccess("Izoh muvaffaqiyatli o'chirildi.");
          setDeleteCommentId(null);
        }}
      />
    </section>
  );
}

interface SectionCardProps {
  title: string;
  icon: ComponentType<{ className?: string }>;
  children: ReactNode;
}

function SectionCard({ title, icon: Icon, children }: SectionCardProps) {
  return (
    <div className="surface-card space-y-4 p-4 sm:p-5">
      <div className="flex items-center gap-2">
        <Icon className="size-4 text-primary" />
        <h3 className="text-base font-semibold text-slate-900">{title}</h3>
      </div>
      {children}
    </div>
  );
}

interface InfoGridItemProps {
  label: string;
  value: string;
}

function InfoGridItem({ label, value }: InfoGridItemProps) {
  return (
    <div className="rounded-xl bg-slate-50 p-3">
      <p className="text-xs uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-1 break-words text-sm font-medium text-slate-800">{value}</p>
    </div>
  );
}
