"use client";

import { type FormEvent, useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { ImagePicker } from "@/components/image-picker";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createLessonSlide, deleteLessonSlide, fetchLessonSlides, type LessonSlideItem } from "@/lib/api/lesson-slides";
import { useAdminStore } from "@/lib/admin-store";
import { notifySuccess } from "@/lib/notify";

export default function SlidesPage() {
  const { courses, lessons } = useAdminStore((state) => state);
  const [slides, setSlides] = useState<LessonSlideItem[]>([]);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [selectedCourseId, setSelectedCourseId] = useState<string>("");
  const [selectedLessonId, setSelectedLessonId] = useState<string>("");
  const [values, setValues] = useState({
    title: "",
    body: "",
    image_url: "",
    order_no: "1",
  });

  const resolvedCourseId = selectedCourseId || courses[0]?.id || "";
  const filteredLessons = lessons.filter((item) => (resolvedCourseId ? item.courseId === resolvedCourseId : true));
  const resolvedLessonId = selectedLessonId || filteredLessons[0]?.id || "";

  useEffect(() => {
    if (!resolvedLessonId) return;
    void fetchLessonSlides(resolvedLessonId).then((items) => setSlides(items));
  }, [resolvedLessonId]);

  const columns = useMemo(
    () => [
      { key: "title", label: "Sarlavha" },
      {
        key: "lesson_id",
        label: "Dars",
        render: (item: LessonSlideItem) => lessons.find((lesson) => lesson.id === item.lesson_id)?.title ?? "Noma'lum",
      },
      { key: "body", label: "Izoh" },
      {
        key: "order_no",
        label: "Tartib",
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: LessonSlideItem) => (
          <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteId(item.id)}>
            O&apos;chirish
          </Button>
        ),
      },
    ],
    [lessons],
  );

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!resolvedLessonId) return;
    void createLessonSlide({
      lesson_id: resolvedLessonId,
      title: values.title,
      body: values.body,
      image_url: values.image_url,
      order_no: Number(values.order_no) || 1,
    }).then((item) => {
      setSlides((prev) => [...prev, item].sort((a, b) => a.order_no - b.order_no));
      setValues({ title: "", body: "", image_url: "", order_no: "1" });
      notifySuccess("Slayd qo'shildi.");
    });
  };

  return (
    <section className="admin-page">
      <AppForm
        title="Darsga slayd qo'shish"
        description="Tanlangan dars ichiga slaydlar shu yerdan qo'shiladi."
        onSubmit={onSubmit}
        submitLabel="Slayd qo'shish"
      >
        <div className="grid gap-2 sm:grid-cols-2">
          <div className="grid gap-2">
            <Label htmlFor="courseSelect">Kurs tanlash</Label>
            <select
              id="courseSelect"
              className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm"
              value={resolvedCourseId}
              onChange={(event) => {
                const courseId = event.target.value;
                setSelectedCourseId(courseId);
                const nextLesson = lessons.find((item) => item.courseId === courseId)?.id ?? "";
                setSelectedLessonId(nextLesson);
              }}
            >
              {courses.map((course) => (
                <option key={course.id} value={course.id}>
                  {course.title_uz}
                </option>
              ))}
            </select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="lessonSelect">Dars tanlash</Label>
            <select
              id="lessonSelect"
              className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm"
              value={resolvedLessonId}
              onChange={(event) => setSelectedLessonId(event.target.value)}
            >
              {filteredLessons.map((lesson) => (
                <option key={lesson.id} value={lesson.id}>
                  {lesson.title}
                </option>
              ))}
            </select>
          </div>
        </div>
        <div className="grid gap-2">
          <Label htmlFor="title">Sarlavha</Label>
          <Input id="title" value={values.title} onChange={(e) => setValues((p) => ({ ...p, title: e.target.value }))} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="body">Izoh</Label>
          <Input
            id="body"
            value={values.body}
            onChange={(e) => setValues((p) => ({ ...p, body: e.target.value }))}
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="order">Tartib raqami</Label>
          <Input id="order" value={values.order_no} onChange={(e) => setValues((p) => ({ ...p, order_no: e.target.value }))} />
        </div>
        <ImagePicker
          label="Slayd rasmi"
          value={values.image_url}
          helperText="Rasm tanlanmasa fallback ishlaydi."
          onChange={(value) => setValues((p) => ({ ...p, image_url: value }))}
        />
      </AppForm>

      <AppTable columns={columns} data={slides} emptyText="Hali slayd qo'shilmagan." />

      <ConfirmDialog
        open={Boolean(deleteId)}
        title="Slaydni o'chirish"
        description="Ushbu slaydni o'chirmoqchimisiz?"
        confirmText="Ha, o'chirish"
        onCancel={() => setDeleteId(null)}
        onConfirm={() => {
          if (!deleteId) return;
          void deleteLessonSlide(deleteId).then(() => {
            setSlides((prev) => prev.filter((item) => item.id !== deleteId));
            notifySuccess("Slayd o'chirildi.");
            setDeleteId(null);
          });
        }}
      />
    </section>
  );
}
