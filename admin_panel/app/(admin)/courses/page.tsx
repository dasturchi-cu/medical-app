"use client";

import Link from "next/link";
import { type Dispatch, type FormEvent, type SetStateAction, useEffect, useMemo, useState } from "react";
import { BlueBanner } from "@/components/blue-banner";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { ImagePicker } from "@/components/image-picker";
import { AppModal } from "@/components/modal";
import { PageSkeleton } from "@/components/page-skeleton";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { adminActions, type Course, useAdminStore } from "@/lib/admin-store";
import { notifySuccess } from "@/lib/notify";

interface CourseFormValues {
  title: string;
  price: string;
  admin_telegram: string;
  image: string;
}

const emptyCourseForm: CourseFormValues = {
  title: "",
  price: "",
  admin_telegram: "Neuroscienceadmin",
  image: "",
};

export default function CoursesPage() {
  const { courses: courseList } = useAdminStore((state) => state);
  const [loading, setLoading] = useState(true);
  const [editCourse, setEditCourse] = useState<Course | null>(null);
  const [deleteCourseId, setDeleteCourseId] = useState<string | null>(null);
  const [formValues, setFormValues] = useState<CourseFormValues>(emptyCourseForm);
  const [editValues, setEditValues] = useState<CourseFormValues>(emptyCourseForm);

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const analytics = useMemo(() => {
    const sold = [...courseList].sort((a, b) => b.sales - a.sales).slice(0, 3);
    const viewed = [...courseList].sort((a, b) => b.views - a.views).slice(0, 3);
    const unsold = courseList.filter((course) => course.sales === 0);
    return { sold, viewed, unsold };
  }, [courseList]);

  const columns = useMemo(
    () => [
      {
        key: "preview",
        label: "Rasm",
        render: (item: Course) =>
          item.image ? (
            <div
              className="h-12 w-20 rounded-xl bg-cover bg-center"
              style={{ backgroundImage: `url(${item.image})` }}
            />
          ) : (
            <BlueBanner />
          ),
      },
      {
        key: "title",
        label: "Nomi",
        render: (item: Course) => (
          <p className="font-medium text-slate-800">{item.title_uz}</p>
        ),
      },
      {
        key: "price",
        label: "Narx",
      },
      {
        key: "admin_telegram",
        label: "Admin",
        render: (item: Course) => `@${item.admin_telegram}`,
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: Course) => (
          <div className="flex flex-wrap items-center gap-2">
            <Link
              href={`/courses/${item.id}`}
              className="inline-flex h-8 items-center rounded-lg border border-slate-200 px-3 text-xs text-slate-700 transition-colors hover:border-primary hover:text-primary"
            >
              Ko&apos;rish
            </Link>
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs hover:border-primary hover:text-primary"
              onClick={() => {
                setEditCourse(item);
                setEditValues({
                  title: item.title_uz,
                  price: item.price,
                  admin_telegram: item.admin_telegram,
                  image: item.image,
                });
              }}
            >
              Tahrirlash
            </Button>
            <Button
              variant="destructive"
              className="h-8 rounded-lg px-3 text-xs"
              onClick={() => setDeleteCourseId(item.id)}
            >
              O&apos;chirish
            </Button>
          </div>
        ),
      },
    ],
    [],
  );

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    adminActions.addCourse({ ...formValues, has_modules: false, modules: [] });
    notifySuccess("Kurs muvaffaqiyatli qo'shildi.");
    setFormValues(emptyCourseForm);
  };

  const onEditSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editCourse) return;
    adminActions.updateCourse(editCourse.id, { ...editValues, has_modules: false, modules: [] });
    notifySuccess("Kurs muvaffaqiyatli yangilandi.");
    setEditCourse(null);
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <AppForm
        title="Kurs yaratish"
        onSubmit={onSubmit}
        submitLabel="Kursni saqlash"
      >
        <LanguageFields values={formValues} onChange={setFormValues} />
        <ImagePicker
          label="Rasm (upload yoki link)"
          value={formValues.image}
          onChange={(value) => setFormValues((prev) => ({ ...prev, image: value }))}
        />
      </AppForm>

      <div className="grid gap-4 lg:grid-cols-3">
        <AnalyticsCard title="Eng ko&apos;p sotilgan kurslar" items={analytics.sold.map((course) => `${course.title_uz} (${course.sales})`)} />
        <AnalyticsCard title="Eng ko&apos;p ko&apos;rilgan kurslar" items={analytics.viewed.map((course) => `${course.title_uz} (${course.views})`)} />
        <AnalyticsCard title="Sotilmagan kurslar" items={analytics.unsold.map((course) => course.title_uz)} />
      </div>

      <AppTable columns={columns} data={courseList} emptyText="Hali kurslar qo&apos;shilmagan." />

      <AppModal
        open={Boolean(editCourse)}
        onOpenChange={(open) => (!open ? setEditCourse(null) : undefined)}
        title="Kursni tahrirlash"
        description="Sarlavhani yangilang, tizim tarjimalarni avtomatik hisoblaydi."
      >
        <AppForm title="Kursni yangilash" submitLabel="Saqlash" onSubmit={onEditSubmit}>
          <LanguageFields values={editValues} onChange={setEditValues} />
          <ImagePicker
            label="Rasm (upload yoki link)"
            value={editValues.image}
            onChange={(value) => setEditValues((prev) => ({ ...prev, image: value }))}
          />
        </AppForm>
      </AppModal>

      <ConfirmDialog
        open={Boolean(deleteCourseId)}
        title="Kursni o&apos;chirish"
        description="Rostdan ham ushbu kursni o&apos;chirmoqchimisiz? Kursga bog&apos;liq darslar ham o&apos;chadi."
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteCourseId(null)}
        onConfirm={() => {
          if (!deleteCourseId) return;
          adminActions.deleteCourse(deleteCourseId);
          notifySuccess("Kurs muvaffaqiyatli o'chirildi.");
          setDeleteCourseId(null);
        }}
      />
    </section>
  );
}

interface LanguageFieldsProps {
  values: CourseFormValues;
  onChange: Dispatch<SetStateAction<CourseFormValues>>;
}

function LanguageFields({ values, onChange }: LanguageFieldsProps) {
  return (
    <div className="space-y-3">
      <div className="grid gap-2">
        <Label htmlFor="title">Kurs sarlavhasi</Label>
        <input
          id="title"
          value={values.title}
          onChange={(event) => onChange((prev) => ({ ...prev, title: event.target.value }))}
          placeholder="Masalan: Kardiologiya asoslari"
          className="h-11 rounded-xl border border-slate-200 px-3 text-sm outline-none focus:border-primary"
        />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="price">Kurs narxi</Label>
        <input
          id="price"
          value={values.price}
          onChange={(event) => onChange((prev) => ({ ...prev, price: event.target.value }))}
          placeholder="Masalan: 299 000 so'm"
          className="h-11 rounded-xl border border-slate-200 px-3 text-sm outline-none focus:border-primary"
        />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="admin_telegram">Kurs admini (Telegram)</Label>
        <input
          id="admin_telegram"
          value={values.admin_telegram}
          onChange={(event) => onChange((prev) => ({ ...prev, admin_telegram: event.target.value }))}
          placeholder="Neuroscienceadmin"
          className="h-11 rounded-xl border border-slate-200 px-3 text-sm outline-none focus:border-primary"
        />
      </div>
    </div>
  );
}

interface AnalyticsCardProps {
  title: string;
  items: string[];
}

function AnalyticsCard({ title, items }: AnalyticsCardProps) {
  return (
    <div className="surface-card p-4">
      <h4 className="mb-2 text-sm font-semibold text-slate-700">{title}</h4>
      {items.length > 0 ? (
        <ul className="space-y-1">
          {items.map((item) => (
            <li key={item} className="text-sm text-slate-600">
              {item}
            </li>
          ))}
        </ul>
      ) : (
        <p className="text-sm text-slate-400">Ma&apos;lumot yo&apos;q.</p>
      )}
    </div>
  );
}

