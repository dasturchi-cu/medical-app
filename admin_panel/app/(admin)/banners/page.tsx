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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { adminActions, courseTitleByLanguage, type Banner, useAdminStore } from "@/lib/admin-store";
import { notifySuccess } from "@/lib/notify";

const DEFAULT_ADMIN_TELEGRAM = "Neuroscienceadmin";

export default function BannersPage() {
  const { courses, banners } = useAdminStore((state) => state);
  const [loading, setLoading] = useState(true);
  const [editBanner, setEditBanner] = useState<Banner | null>(null);
  const [deleteBannerId, setDeleteBannerId] = useState<string | null>(null);
  const [formValues, setFormValues] = useState({
    title: "",
    message: "",
    price: "",
    image: "",
    course_id: (courses[0]?.id ?? "") as string | null,
  });
  const [editValues, setEditValues] = useState({
    title: "",
    message: "",
    price: "",
    image: "",
    course_id: (courses[0]?.id ?? "") as string | null,
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
        render: (item: Banner) =>
          item.image ? (
            <div
              className="h-12 w-20 rounded-xl bg-cover bg-center"
              style={{ backgroundImage: `url(${item.image})` }}
            />
          ) : (
            <BlueBanner />
          ),
      },
      { key: "title", label: "Banner nomi" },
      {
        key: "message",
        label: "Nima haqida",
        render: (item: Banner) => <span className="line-clamp-2 max-w-[220px]">{item.message}</span>,
      },
      { key: "price", label: "Narx" },
      {
        key: "courseId",
        label: "Kurs",
        render: (item: Banner) => {
          const course = courses.find((entry) => entry.id === item.courseId);
          return course ? courseTitleByLanguage(course, "uz") : item.courseId;
        },
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: Banner) => {
          return (
            <div className="flex flex-wrap gap-2">
              <a
                href={telegramLink(courses.find((entry) => entry.id === item.courseId)?.admin_telegram, item.title, item.price)}
                target="_blank"
                rel="noreferrer"
                className="inline-flex h-8 items-center rounded-lg bg-primary px-3 text-xs text-white"
              >
                Adminga yozish
              </a>
              <Button
                variant="outline"
                className="h-8 rounded-lg border-slate-200 px-3 text-xs"
                onClick={() => {
                  setEditBanner(item);
                  setEditValues({
                    title: item.title,
                    message: item.message,
                  price: item.price,
                    image: item.image,
                    course_id: item.courseId,
                  });
                }}
              >
                Tahrirlash
              </Button>
              <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteBannerId(item.id)}>
                O&apos;chirish
              </Button>
            </div>
          );
        },
      },
    ],
    [courses],
  );

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    adminActions.addBanner({
      title: formValues.title,
      message: formValues.message,
      price: formValues.price.trim() || "Kelishiladi",
      telegram: DEFAULT_ADMIN_TELEGRAM,
      image: formValues.image,
      courseId: formValues.course_id ?? "",
    });
    notifySuccess("Kurs reklamasi muvaffaqiyatli qo'shildi.");
    setFormValues({
      title: "",
      message: "",
      price: "",
      image: "",
      course_id: courses[0]?.id ?? "",
    });
  };

  const onEditSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editBanner) return;
    adminActions.updateBanner(editBanner.id, {
      title: editValues.title,
      message: editValues.message,
      price: editValues.price.trim() || "Kelishiladi",
      telegram: DEFAULT_ADMIN_TELEGRAM,
      image: editValues.image ?? "",
      courseId: editValues.course_id ?? "",
    });
    notifySuccess("Kurs reklamasi muvaffaqiyatli yangilandi.");
    setEditBanner(null);
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <AppForm title="Kurs reklamasi yaratish" description="Reklama orqali foydalanuvchi onlayn kursga qiziqadi va adminga yozadi." onSubmit={onSubmit}>
        <div className="grid gap-2">
          <Label htmlFor="title">Reklama sarlavhasi</Label>
          <Input
            id="title"
            value={formValues.title}
            onChange={(event) => setFormValues((prev) => ({ ...prev, title: event.target.value }))}
            placeholder="Masalan: Diqqat va fokus kursi"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="message">Reklama matni (nima haqida?)</Label>
          <Input
            id="message"
            value={formValues.message}
            onChange={(event) => setFormValues((prev) => ({ ...prev, message: event.target.value }))}
            placeholder="Masalan: Bu banner diqqatni oshirish kursi haqida"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>
        <div className="grid gap-2 sm:grid-cols-2">
          <div className="grid gap-2">
            <Label htmlFor="price">Kurs narxi</Label>
            <Input
              id="price"
              value={formValues.price}
              onChange={(event) => setFormValues((prev) => ({ ...prev, price: event.target.value }))}
              placeholder="Masalan: 299 000 so&apos;m"
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="rounded-xl border border-blue-100 bg-blue-50/70 px-3 py-2 text-xs text-blue-700">
            Mijoz kurs adminiga yozadi. Admin kurs ichida sozlanadi.
          </div>
        </div>
        <ImagePicker
          label="Rasm (upload yoki link)"
          value={formValues.image}
          helperText="Rasm qo&apos;yilmasa, avtomatik ko&apos;k banner ishlatiladi."
          onChange={(value) => setFormValues((prev) => ({ ...prev, image: value }))}
        />

        <div className="grid gap-2">
          <Label htmlFor="course_id">Qaysi onlayn kursga tegishli?</Label>
          <Select value={formValues.course_id ?? ""} onValueChange={(value) => setFormValues((prev) => ({ ...prev, course_id: value }))}>
            <SelectTrigger id="course_id" className="h-11 rounded-xl border-slate-200">
              <SelectValue placeholder="Kursni tanlang">
                {courses.find((course) => course.id === formValues.course_id)?.title_uz ?? "Kursni tanlang"}
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
      </AppForm>

      <AppTable columns={columns} data={banners} emptyText="Hali bannerlar qo&apos;shilmagan." />

      <AppModal
        open={Boolean(editBanner)}
        onOpenChange={(open) => (!open ? setEditBanner(null) : undefined)}
        title="Reklamani tahrirlash"
        description="Reklama ma&apos;lumotlarini yangilang."
      >
        <AppForm title="Reklamani yangilash" submitLabel="Saqlash" onSubmit={onEditSubmit}>
          <div className="grid gap-2">
            <Label htmlFor="edit_banner_title">Reklama sarlavhasi</Label>
            <Input
              id="edit_banner_title"
              value={editValues.title}
              onChange={(event) => setEditValues((prev) => ({ ...prev, title: event.target.value }))}
              placeholder="Masalan: Diqqat va fokus kursi"
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit_banner_message">Reklama matni (nima haqida?)</Label>
            <Input
              id="edit_banner_message"
              value={editValues.message}
              onChange={(event) => setEditValues((prev) => ({ ...prev, message: event.target.value }))}
              placeholder="Masalan: Bu banner diqqatni oshirish kursi haqida"
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="grid gap-2 sm:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="edit_banner_price">Kurs narxi</Label>
              <Input
                id="edit_banner_price"
                value={editValues.price}
                onChange={(event) => setEditValues((prev) => ({ ...prev, price: event.target.value }))}
                placeholder="Masalan: 299 000 so&apos;m"
                className="h-11 rounded-xl border-slate-200"
              />
            </div>
            <div className="rounded-xl border border-blue-100 bg-blue-50/70 px-3 py-2 text-xs text-blue-700">
              Mijoz kurs adminiga yozadi. Admin kurs ichida sozlanadi.
            </div>
          </div>
          <ImagePicker
            label="Rasm (upload yoki link)"
            value={editValues.image ?? ""}
            helperText="Rasm qo&apos;yilmasa, avtomatik ko&apos;k banner ishlatiladi."
            onChange={(value) => setEditValues((prev) => ({ ...prev, image: value }))}
          />
          <div className="grid gap-2">
            <Label htmlFor="edit_banner_course">Qaysi onlayn kursga tegishli?</Label>
            <Select value={editValues.course_id ?? ""} onValueChange={(value) => setEditValues((prev) => ({ ...prev, course_id: value }))}>
              <SelectTrigger id="edit_banner_course" className="h-11 rounded-xl border-slate-200">
                <SelectValue placeholder="Kursni tanlang">
                  {courses.find((course) => course.id === editValues.course_id)?.title_uz ?? "Kursni tanlang"}
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
        </AppForm>
      </AppModal>

      <ConfirmDialog
        open={Boolean(deleteBannerId)}
        title="Reklamani o&apos;chirish"
        description="Rostdan ham ushbu reklamani o&apos;chirmoqchimisiz?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteBannerId(null)}
        onConfirm={() => {
          if (!deleteBannerId) return;
          adminActions.deleteBanner(deleteBannerId);
          notifySuccess("Kurs reklamasi muvaffaqiyatli o'chirildi.");
          setDeleteBannerId(null);
        }}
      />
    </section>
  );
}

function telegramLink(adminTelegram: string | undefined, title: string, price: string) {
  const handle = adminTelegram?.replace(/^@/, "").trim() || DEFAULT_ADMIN_TELEGRAM;
  const text = encodeURIComponent(`Salom, "${title}" kursini sotib olmoqchiman. Narx: ${price || "kelishiladi"}.`);
  return `https://t.me/${handle}?text=${text}`;
}
