"use client";

import Link from "next/link";
import { type Dispatch, type FormEvent, type SetStateAction, useEffect, useMemo, useState } from "react";
import { BlueBanner } from "@/components/blue-banner";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { CoursePreview } from "@/components/course-preview";
import { AppForm } from "@/components/form";
import { ImagePicker } from "@/components/image-picker";
import { MobilePreview } from "@/components/mobile-preview";
import { AppModal } from "@/components/modal";
import { PageSkeleton } from "@/components/page-skeleton";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { adminActions, type Course, useAdminStore } from "@/lib/admin-store";

interface CourseFormValues {
  title: string;
  image: string;
  has_modules: boolean;
  modules: string[];
}

const emptyCourseForm: CourseFormValues = {
  title: "",
  image: "",
  has_modules: false,
  modules: [],
};

export default function CoursesPage() {
  const { courses: courseList, courseModules } = useAdminStore((state) => state);
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
          <div>
            <p className="font-medium text-slate-800">{item.title_uz}</p>
            <p className="text-xs text-slate-500">RU: {item.title_ru}</p>
            <p className="text-xs text-slate-500">EN: {item.title_en}</p>
          </div>
        ),
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
                  image: item.image,
                  has_modules: item.has_modules,
                  modules: courseModules
                    .filter((module) => module.course_id === item.id)
                    .map((module) => module.name),
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
    [courseModules],
  );

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    adminActions.addCourse(formValues);
    setFormValues(emptyCourseForm);
  };

  const onEditSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editCourse) return;
    adminActions.updateCourse(editCourse.id, editValues);
    setEditCourse(null);
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="space-y-6">
      <div className="grid gap-6 lg:grid-cols-[1.5fr_1fr]">
        <AppForm
          title="Kurs yaratish"
          description="Sarlavhani kiriting, tizim avtomatik UZ / RU / EN versiyalarini yaratadi."
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

        <MobilePreview title="Live Mobile Preview" subtitle="Kurs ma&apos;lumotlari real vaqtda">
          <CoursePreview
            title={formValues.title}
            image={formValues.image}
            videoCount={courseList[0] ? 12 : 0}
            sampleCourses={courseList.map((course) => course.title_uz)}
          />
        </MobilePreview>
      </div>

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
    <div className="space-y-4">
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

      <div className="rounded-xl border border-slate-100 p-4">
        <Label className="mb-2 block">Bu kursda bazalar bormi?</Label>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            className={`rounded-lg px-3 py-2 text-xs ${values.has_modules ? "bg-primary text-white" : "bg-slate-100 text-slate-600"}`}
            onClick={() => onChange((prev) => ({ ...prev, has_modules: true, modules: prev.modules.length > 0 ? prev.modules : ["1-baza"] }))}
          >
            Ha
          </button>
          <button
            type="button"
            className={`rounded-lg px-3 py-2 text-xs ${!values.has_modules ? "bg-primary text-white" : "bg-slate-100 text-slate-600"}`}
            onClick={() => onChange((prev) => ({ ...prev, has_modules: false, modules: [] }))}
          >
            Yo&apos;q
          </button>
        </div>
      </div>

      {values.has_modules ? (
        <div className="space-y-2 rounded-xl border border-slate-100 p-4">
          <div className="flex items-center justify-between">
            <Label>Modullar ro&apos;yxati</Label>
            <button
              type="button"
              className="rounded-lg bg-slate-100 px-3 py-1 text-xs text-slate-600"
              onClick={() => onChange((prev) => ({ ...prev, modules: [...prev.modules, `${prev.modules.length + 1}-baza`] }))}
            >
              + Add module
            </button>
          </div>
          {values.modules.map((moduleName, index) => (
            <input
              key={`${moduleName}-${index}`}
              value={moduleName}
              onChange={(event) =>
                onChange((prev) => ({
                  ...prev,
                  modules: prev.modules.map((item, itemIndex) => (itemIndex === index ? event.target.value : item)),
                }))
              }
              className="h-10 w-full rounded-lg border border-slate-200 px-3 text-sm outline-none focus:border-primary"
              placeholder={`${index + 1}-baza`}
            />
          ))}
        </div>
      ) : null}
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
