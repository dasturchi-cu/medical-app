"use client";

import { type FormEvent, useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { AppModal } from "@/components/modal";
import { PageSkeleton } from "@/components/page-skeleton";
import { AppTable } from "@/components/table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { adminActions, type Lesson, useAdminStore } from "@/lib/admin-store";

export default function LessonsPage() {
  const { courses, lessons } = useAdminStore((state) => state);
  const [loading, setLoading] = useState(true);
  const [selectedCourse, setSelectedCourse] = useState(courses[0]?.id ?? "");
  const [editLesson, setEditLesson] = useState<Lesson | null>(null);
  const [deleteLessonId, setDeleteLessonId] = useState<string | null>(null);
  const [formValues, setFormValues] = useState({
    title: "",
    videoId: "",
    order: "1",
    isFree: false,
  });
  const [editValues, setEditValues] = useState({
    title: "",
    videoId: "",
    order: "1",
    isFree: false,
  });

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const selectedCourseData = courses.find((course) => course.id === selectedCourse);

  const columns = useMemo(
    () => [
      { key: "title", label: "Nomi" },
      { key: "videoId", label: "videoId (YouTube)" },
      { key: "order", label: "Tartib" },
      {
        key: "isFree",
        label: "Kirish turi",
        render: (item: Lesson) => (
          <Badge variant="secondary" className="rounded-lg bg-slate-100 text-slate-700">
            {item.isFree ? "Bepul" : "Pullik"}
          </Badge>
        ),
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: Lesson) => (
          <div className="flex flex-wrap gap-2">
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs"
              onClick={() => {
                setEditLesson(item);
                setEditValues({
                  title: item.title,
                  videoId: item.videoId,
                  order: String(item.order),
                  isFree: item.isFree,
                });
              }}
            >
              Tahrirlash
            </Button>
            <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteLessonId(item.id)}>
              O&apos;chirish
            </Button>
          </div>
        ),
      },
    ],
    [],
  );

  const filteredLessons = lessons
    .filter((lesson) => lesson.courseId === selectedCourse)
    .sort((a, b) => a.order - b.order);

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    adminActions.addLesson({
      courseId: selectedCourse,
      title: formValues.title,
      videoId: formValues.videoId,
      order: Number(formValues.order),
      module_id: null,
      isFree: formValues.isFree,
    });
    setFormValues((prev) => ({ ...prev, title: "", videoId: "", order: "1", isFree: false }));
  };

  const onEditSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editLesson) return;
    adminActions.updateLesson(editLesson.id, {
      courseId: selectedCourse,
      title: editValues.title,
      videoId: editValues.videoId,
      order: Number(editValues.order),
      module_id: null,
      isFree: editValues.isFree,
    });
    setEditLesson(null);
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="grid gap-6 lg:grid-cols-[1fr_390px]">
      <div className="space-y-4">
        <div className="surface-card space-y-4 p-6">
          <div>
            <h3 className="text-base font-semibold text-slate-900">Filtrlar</h3>
            <p className="text-sm text-slate-500">Kursni tanlab, kerakli darslarni boshqaring.</p>
          </div>
          <Label className="mb-2 block text-sm text-slate-600">Kursni tanlang</Label>
          <Select value={selectedCourse} onValueChange={(value) => setSelectedCourse(value ?? "")}>
            <SelectTrigger className="h-11 w-full rounded-xl border-slate-200">
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
        </div>

        <AppTable columns={columns} data={filteredLessons} emptyText="Bu kurs uchun hali darslar yo&apos;q." />
      </div>

      <AppForm title="Dars qo&apos;shish" description="Tanlangan kurs uchun yangi dars yarating." onSubmit={onSubmit}>
          <div className="grid gap-2">
            <Label htmlFor="title">Dars nomi - title</Label>
            <Input
              id="title"
              value={formValues.title}
              onChange={(event) => setFormValues((prev) => ({ ...prev, title: event.target.value }))}
              placeholder="Dars nomi"
              className="h-11 rounded-xl border-slate-200"
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="videoId">YouTube video kodi - videoId</Label>
            <Input
              id="videoId"
              value={formValues.videoId}
              onChange={(event) => setFormValues((prev) => ({ ...prev, videoId: event.target.value }))}
              placeholder="Masalan: ab12CdE"
              className="h-11 rounded-xl border-slate-200"
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="order">Bu nechanchi dars (order)</Label>
            <Input
              id="order"
              type="number"
              min={1}
              value={formValues.order}
              onChange={(event) => setFormValues((prev) => ({ ...prev, order: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>

          <div className="flex items-center justify-between rounded-xl border border-slate-100 px-4 py-3">
            <Label htmlFor="isFree" className="text-sm text-slate-700">
              Bepul dars
            </Label>
            <Switch
              id="isFree"
              checked={formValues.isFree}
              onCheckedChange={(value) => setFormValues((prev) => ({ ...prev, isFree: value }))}
            />
          </div>
      </AppForm>

      <AppModal
        open={Boolean(editLesson)}
        onOpenChange={(open) => (!open ? setEditLesson(null) : undefined)}
        title="Darsni tahrirlash"
        description="Dars ma&apos;lumotlarini yangilang."
      >
        <AppForm title="Darsni yangilash" submitLabel="Saqlash" onSubmit={onEditSubmit}>
          <div className="grid gap-2">
            <Label htmlFor="edit_title">Dars nomi</Label>
            <Input
              id="edit_title"
              value={editValues.title}
              onChange={(event) => setEditValues((prev) => ({ ...prev, title: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit_video">YouTube video kodi</Label>
            <Input
              id="edit_video"
              value={editValues.videoId}
              onChange={(event) => setEditValues((prev) => ({ ...prev, videoId: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit_order">Bu nechanchi dars (order)</Label>
            <Input
              id="edit_order"
              type="number"
              min={1}
              value={editValues.order}
              onChange={(event) => setEditValues((prev) => ({ ...prev, order: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="flex items-center justify-between rounded-xl border border-slate-100 px-4 py-3">
            <Label htmlFor="edit_is_free" className="text-sm text-slate-700">
              Bepul dars
            </Label>
            <Switch
              id="edit_is_free"
              checked={editValues.isFree}
              onCheckedChange={(value) => setEditValues((prev) => ({ ...prev, isFree: value }))}
            />
          </div>
        </AppForm>
      </AppModal>

      <ConfirmDialog
        open={Boolean(deleteLessonId)}
        title="Darsni o&apos;chirish"
        description="Rostdan ham ushbu darsni o&apos;chirmoqchimisiz?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteLessonId(null)}
        onConfirm={() => {
          if (!deleteLessonId) return;
          adminActions.deleteLesson(deleteLessonId);
          setDeleteLessonId(null);
        }}
      />
    </section>
  );
}
