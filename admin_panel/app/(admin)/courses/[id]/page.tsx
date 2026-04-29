"use client";

import { type ComponentType, type FormEvent, useMemo, useState } from "react";
import { useParams } from "next/navigation";
import { BarChart3, MessageSquare, Star, Users, Video } from "lucide-react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { AppModal } from "@/components/modal";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { adminActions, type Lesson, useAdminStore } from "@/lib/admin-store";

export default function CourseDetailPage() {
  const { id } = useParams<{ id: string }>();
  const state = useAdminStore((current) => current);
  const [editLesson, setEditLesson] = useState<Lesson | null>(null);
  const [deleteLessonId, setDeleteLessonId] = useState<string | null>(null);
  const [deleteCommentId, setDeleteCommentId] = useState<string | null>(null);
  const [editValues, setEditValues] = useState({
    title: "",
    videoId: "",
    order: "1",
  });

  const course = state.courses.find((item) => item.id === id);
  const lessons = useMemo(
    () => state.lessons.filter((item) => item.courseId === id).sort((a, b) => a.order - b.order),
    [id, state.lessons],
  );
  const buyers = useMemo(
    () =>
      state.userCourses
        .filter((item) => item.course_id === id && item.is_active)
        .map((relation) => ({
          user: state.users.find((user) => user.id === relation.user_id),
          purchasedAt: relation.purchased_at,
        }))
        .filter((item): item is { user: (typeof state.users)[number]; purchasedAt: string } => Boolean(item.user)),
    [id, state],
  );
  const ratings = useMemo(() => state.ratings.filter((item) => item.course_id === id), [id, state.ratings]);
  const comments = useMemo(() => state.comments.filter((item) => item.course_id === id), [id, state.comments]);

  const avgRating =
    ratings.length > 0
      ? (ratings.reduce((sum, item) => sum + item.rating, 0) / ratings.length).toFixed(1)
      : "0.0";

  const onEditLesson = (lesson: Lesson) => {
    setEditLesson(lesson);
    setEditValues({
      title: lesson.title,
      videoId: lesson.videoId,
      order: String(lesson.order),
    });
  };

  const onSubmitEdit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editLesson) return;
    adminActions.updateLesson(editLesson.id, {
      courseId: editLesson.courseId,
      module_id: editLesson.module_id,
      title: editValues.title,
      videoId: editValues.videoId,
      order: Number(editValues.order),
      isFree: editLesson.isFree,
    });
    setEditLesson(null);
  };

  if (!course) {
    return (
      <div className="surface-card p-8 text-center text-sm text-slate-500">
        Kurs topilmadi.
      </div>
    );
  }

  return (
    <section className="admin-page">
      <div className="surface-card p-4 sm:p-5">
        <h2 className="text-xl font-semibold text-slate-900 sm:text-2xl">{course.title_uz}</h2>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <InfoCard icon={Video} title="Videolar soni" value={String(lessons.length)} />
        <InfoCard icon={Users} title="Sotib olgan userlar" value={String(buyers.length)} />
        <InfoCard icon={BarChart3} title="Ko&apos;rishlar soni" value={String(course.views)} />
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="surface-card p-4">
          <div className="mb-3 flex items-center gap-2">
            <Star className="size-4 text-primary" />
            <h3 className="font-semibold text-slate-800">Reyting</h3>
          </div>
          <p className="text-lg font-semibold text-slate-900">{avgRating} ⭐</p>
          <p className="text-sm text-slate-500">{ratings.length} ta ovoz</p>
        </div>

        <div className="surface-card p-4">
          <div className="mb-3 flex items-center gap-2">
            <Users className="size-4 text-primary" />
            <h3 className="font-semibold text-slate-800">Xaridorlar</h3>
          </div>
          <div className="space-y-2">
            {buyers.length > 0 ? (
              buyers.map((item) => (
                <div key={item.user.id} className="rounded-xl bg-slate-50 px-3 py-2">
                  <p className="text-sm text-slate-800">{item.user.name}</p>
                  <p className="text-xs text-slate-500">{item.purchasedAt || "Qo'lda ochilgan"}</p>
                </div>
              ))
            ) : (
              <p className="text-sm text-slate-400">Hozircha xaridor yo&apos;q.</p>
            )}
          </div>
        </div>
      </div>

      <div className="surface-card p-4">
        <div className="mb-3 flex items-center gap-2">
          <Video className="size-4 text-primary" />
          <h3 className="font-semibold text-slate-800">Video ro&apos;yxati</h3>
        </div>
        <div className="space-y-2">
          {lessons.map((lesson) => (
            <div key={lesson.id} className="flex flex-wrap items-start justify-between gap-3 rounded-xl bg-slate-50 px-3 py-2">
              <div className="min-w-0">
                <p className="font-medium text-slate-800">
                  {lesson.order}. {lesson.title}
                </p>
                <p className="break-all text-xs text-slate-500">{lesson.videoId}</p>
              </div>
              <div className="flex w-full flex-wrap gap-2 sm:w-auto sm:justify-end">
                <Button
                  variant="outline"
                  className="h-8 rounded-lg border-slate-200 px-3 text-xs"
                  onClick={() => adminActions.reorderLesson(course.id, lesson.id, "up")}
                >
                  Yuqoriga
                </Button>
                <Button
                  variant="outline"
                  className="h-8 rounded-lg border-slate-200 px-3 text-xs"
                  onClick={() => adminActions.reorderLesson(course.id, lesson.id, "down")}
                >
                  Pastga
                </Button>
                <Button
                  variant="outline"
                  className="h-8 rounded-lg border-slate-200 px-3 text-xs"
                  onClick={() => onEditLesson(lesson)}
                >
                  Tahrirlash
                </Button>
                <Button
                  variant="destructive"
                  className="h-8 rounded-lg px-3 text-xs"
                  onClick={() => setDeleteLessonId(lesson.id)}
                >
                  O&apos;chirish
                </Button>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="surface-card p-4">
        <div className="mb-3 flex items-center gap-2">
          <MessageSquare className="size-4 text-primary" />
          <h3 className="font-semibold text-slate-800">Izohlar</h3>
        </div>
        <div className="space-y-2">
          {comments.length > 0 ? (
            comments.map((comment) => {
              const user = state.users.find((entry) => entry.id === comment.user_id);
              return (
                <div key={comment.id} className="flex flex-col gap-2 rounded-xl bg-slate-50 px-3 py-2 sm:flex-row sm:items-center sm:justify-between">
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-slate-800">{user?.name ?? comment.user_id}</p>
                    <p className="text-sm text-slate-600">{comment.text}</p>
                  </div>
                  <Button
                    variant="destructive"
                    className="h-8 w-full rounded-lg px-3 text-xs sm:w-auto"
                    onClick={() => setDeleteCommentId(comment.id)}
                  >
                    O&apos;chirish
                  </Button>
                </div>
              );
            })
          ) : (
            <p className="text-sm text-slate-400">Izohlar yo&apos;q.</p>
          )}
        </div>
      </div>

      <AppModal
        open={Boolean(editLesson)}
        onOpenChange={(open) => (!open ? setEditLesson(null) : undefined)}
        title="Videoni tahrirlash"
      >
        <AppForm title="Video ma&apos;lumotlari" submitLabel="Saqlash" onSubmit={onSubmitEdit}>
          <div className="grid gap-2">
            <Label htmlFor="edit-title">Sarlavha</Label>
            <Input id="edit-title" value={editValues.title} onChange={(event) => setEditValues((prev) => ({ ...prev, title: event.target.value }))} className="h-11 rounded-xl border-slate-200" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit-videoid">Video ID</Label>
            <Input id="edit-videoid" value={editValues.videoId} onChange={(event) => setEditValues((prev) => ({ ...prev, videoId: event.target.value }))} className="h-11 rounded-xl border-slate-200" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit-order">Order</Label>
            <Input id="edit-order" type="number" min={1} value={editValues.order} onChange={(event) => setEditValues((prev) => ({ ...prev, order: event.target.value }))} className="h-11 rounded-xl border-slate-200" />
          </div>
        </AppForm>
      </AppModal>

      <ConfirmDialog
        open={Boolean(deleteLessonId)}
        title="Videoni o&apos;chirish"
        description="Ushbu videoni o&apos;chirishni tasdiqlaysizmi?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteLessonId(null)}
        onConfirm={() => {
          if (!deleteLessonId) return;
          adminActions.deleteLesson(deleteLessonId);
          setDeleteLessonId(null);
        }}
      />

      <ConfirmDialog
        open={Boolean(deleteCommentId)}
        title="Izohni o&apos;chirish"
        description="Ushbu izohni o&apos;chirishni tasdiqlaysizmi?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteCommentId(null)}
        onConfirm={() => {
          if (!deleteCommentId) return;
          adminActions.deleteComment(deleteCommentId);
          setDeleteCommentId(null);
        }}
      />
    </section>
  );
}

interface InfoCardProps {
  icon: ComponentType<{ className?: string }>;
  title: string;
  value: string;
}

function InfoCard({ icon: Icon, title, value }: InfoCardProps) {
  return (
    <div className="surface-card p-4">
      <div className="mb-2 flex items-center gap-2">
        <Icon className="size-4 text-primary" />
        <p className="text-sm text-slate-500">{title}</p>
      </div>
      <p className="text-2xl font-semibold text-slate-900">{value}</p>
    </div>
  );
}
