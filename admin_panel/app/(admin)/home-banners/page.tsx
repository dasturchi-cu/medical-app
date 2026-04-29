"use client";

import { type FormEvent, useEffect, useMemo, useState } from "react";
import { BlueBanner } from "@/components/blue-banner";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { ImagePicker } from "@/components/image-picker";
import { AppModal } from "@/components/modal";
import { PageSkeleton } from "@/components/page-skeleton";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { adminActions, type HomeBanner, useAdminStore } from "@/lib/admin-store";
import { notifySuccess } from "@/lib/notify";

export default function HomeBannersPage() {
  const { courses, homeBanners } = useAdminStore((state) => state);
  const [loading, setLoading] = useState(true);
  const [editBanner, setEditBanner] = useState<HomeBanner | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [formValues, setFormValues] = useState({
    title: "",
    button_text: "Boshlash",
    image: "",
    course_id: courses[0]?.id ?? "",
  });
  const [editValues, setEditValues] = useState({
    title: "",
    button_text: "Boshlash",
    image: "",
    course_id: courses[0]?.id ?? "",
  });

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const columns = useMemo(
    () => [
      {
        key: "preview",
        label: "Ko&apos;rinish",
        render: (item: HomeBanner) =>
          item.image ? (
            <div className="h-12 w-20 rounded-xl bg-cover bg-center" style={{ backgroundImage: `url(${item.image})` }} />
          ) : (
            <BlueBanner />
          ),
      },
      { key: "title", label: "Banner matni" },
      { key: "button_text", label: "Tugma" },
      {
        key: "courseId",
        label: "Kurs",
        render: (item: HomeBanner) => courses.find((course) => course.id === item.courseId)?.title_uz ?? item.courseId,
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: HomeBanner) => (
          <div className="flex flex-wrap gap-2">
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs"
              onClick={() => {
                setEditBanner(item);
                setEditValues({
                  title: item.title,
                  button_text: item.button_text,
                  image: item.image,
                  course_id: item.courseId,
                });
              }}
            >
              Tahrirlash
            </Button>
            <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteId(item.id)}>
              O&apos;chirish
            </Button>
          </div>
        ),
      },
    ],
    [courses],
  );

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    adminActions.addHomeBanner({
      title: formValues.title.trim(),
      button_text: formValues.button_text.trim() || "Boshlash",
      image: formValues.image,
      courseId: formValues.course_id,
    });
    notifySuccess("Home reklama muvaffaqiyatli qo'shildi.");
    setFormValues({
      title: "",
      button_text: "Boshlash",
      image: "",
      course_id: courses[0]?.id ?? "",
    });
  };

  const onEditSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editBanner) return;
    adminActions.updateHomeBanner(editBanner.id, {
      title: editValues.title.trim(),
      button_text: editValues.button_text.trim() || "Boshlash",
      image: editValues.image,
      courseId: editValues.course_id,
    });
    notifySuccess("Home reklama muvaffaqiyatli yangilandi.");
    setEditBanner(null);
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <AppForm title="Home reklama yaratish" description="Ko&apos;k slider uchun reklama qo&apos;shing." onSubmit={onSubmit}>
        <div className="grid gap-2">
          <Label htmlFor="title">Banner matni</Label>
          <Input
            id="title"
            value={formValues.title}
            onChange={(event) => setFormValues((prev) => ({ ...prev, title: event.target.value }))}
            placeholder="Masalan: Nevron tarmoqlari"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="button_text">Tugma matni</Label>
          <Input
            id="button_text"
            value={formValues.button_text}
            onChange={(event) => setFormValues((prev) => ({ ...prev, button_text: event.target.value }))}
            placeholder="Boshlash"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>
        <ImagePicker
          label="Rasm (upload yoki link)"
          value={formValues.image}
          helperText="Rasm qo&apos;yilmasa, default ko&apos;k uslub ishlatiladi."
          onChange={(value) => setFormValues((prev) => ({ ...prev, image: value }))}
        />
      </AppForm>

      <AppTable columns={columns} data={homeBanners} emptyText="Hali home reklamalar qo&apos;shilmagan." />

      <AppModal
        open={Boolean(editBanner)}
        onOpenChange={(open) => (!open ? setEditBanner(null) : undefined)}
        title="Home reklamani tahrirlash"
        description="Reklama ma&apos;lumotlarini yangilang."
      >
        <AppForm title="Home reklamani yangilash" submitLabel="Saqlash" onSubmit={onEditSubmit}>
          <div className="grid gap-2">
            <Label htmlFor="edit_title">Banner matni</Label>
            <Input
              id="edit_title"
              value={editValues.title}
              onChange={(event) => setEditValues((prev) => ({ ...prev, title: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit_button_text">Tugma matni</Label>
            <Input
              id="edit_button_text"
              value={editValues.button_text}
              onChange={(event) => setEditValues((prev) => ({ ...prev, button_text: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <ImagePicker
            label="Rasm (upload yoki link)"
            value={editValues.image}
            helperText="Rasm qo&apos;yilmasa, default ko&apos;k uslub ishlatiladi."
            onChange={(value) => setEditValues((prev) => ({ ...prev, image: value }))}
          />
        </AppForm>
      </AppModal>

      <ConfirmDialog
        open={Boolean(deleteId)}
        title="Home reklamani o&apos;chirish"
        description="Rostdan ham ushbu reklamani o&apos;chirmoqchimisiz?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteId(null)}
        onConfirm={() => {
          if (!deleteId) return;
          adminActions.deleteHomeBanner(deleteId);
          notifySuccess("Home reklama muvaffaqiyatli o'chirildi.");
          setDeleteId(null);
        }}
      />
    </section>
  );
}
