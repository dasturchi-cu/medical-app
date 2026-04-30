"use client";

import { type FormEvent, useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppModal } from "@/components/modal";
import { StatusModal } from "@/components/status-modal";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createAd, fetchAds, removeAd, type AdItem, updateAd } from "@/lib/api/ads";
import { fetchCourses } from "@/lib/api/courses";
import { notifyError, notifySuccess } from "@/lib/notify";
import { useStatusModal } from "@/lib/use-status-modal";

export default function AdsPage() {
  const [ads, setAds] = useState<AdItem[]>([]);
  const [courses, setCourses] = useState<Array<{ id: string; title_uz: string }>>([]);
  const [loading, setLoading] = useState(true);
  const [editAd, setEditAd] = useState<AdItem | null>(null);
  const [deleteAdId, setDeleteAdId] = useState<string | null>(null);
  const [formValues, setFormValues] = useState({ title: "", message: "", price: "", image: "", courseId: "" });
  const [editValues, setEditValues] = useState({ title: "", message: "", price: "", image: "", courseId: "" });
  const statusModal = useStatusModal();

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const [adItems, courseItems] = await Promise.all([fetchAds(), fetchCourses()]);
        if (!mounted) return;
        setAds(adItems);
        const mapped = courseItems.map((item) => ({ id: item.id, title_uz: item.title_uz }));
        setCourses(mapped);
        setFormValues((prev) => ({ ...prev, courseId: mapped[0]?.id ?? "" }));
      } catch (error) {
        if (!mounted) return;
        notifyError(error instanceof Error ? error.message : "Reklamalar yuklanmadi.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    return () => {
      mounted = false;
    };
  }, []);

  const columns = useMemo(
    () => [
      { key: "title", label: "Sarlavha" },
      { key: "message", label: "Matn" },
      { key: "price_label", label: "Narx" },
      {
        key: "actions",
        label: "Amallar",
        render: (item: AdItem) => (
          <div className="flex gap-2">
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs"
              onClick={() => {
                setEditAd(item);
                setEditValues({
                  title: item.title,
                  message: item.message,
                  price: item.price_label,
                  image: item.image_url,
                  courseId: item.course_id ?? "",
                });
              }}
            >
              Tahrirlash
            </Button>
            <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteAdId(item.id)}>
              O&apos;chirish
            </Button>
          </div>
        ),
      },
    ],
    [],
  );

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!formValues.courseId) return notifyError("Kurs tanlang.");
    try {
      const created = await statusModal.run({
        loadingMessage: "Reklama saqlanmoqda...",
        successMessage: "Reklama muvaffaqiyatli saqlandi",
        errorMessage: "Ad qo'shilmadi.",
        action: async () => createAd({
          title: formValues.title.trim(),
          message: formValues.message.trim(),
          price_label: formValues.price.trim(),
          image_url: formValues.image.trim(),
          course_id: formValues.courseId,
          telegram: "Neuroscienceadmin",
        }),
      });
      setAds((prev) => [created, ...prev]);
      notifySuccess("Ad qo'shildi.");
      setFormValues((prev) => ({ ...prev, title: "", message: "", price: "", image: "" }));
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Ad qo'shilmadi.");
    }
  };

  return (
    <section className="admin-page space-y-4">
      <form onSubmit={onSubmit} className="surface-card grid gap-3 p-4 lg:grid-cols-5">
        <Field label="Sarlavha" value={formValues.title} onChange={(value) => setFormValues((prev) => ({ ...prev, title: value }))} />
        <Field label="Matn" value={formValues.message} onChange={(value) => setFormValues((prev) => ({ ...prev, message: value }))} />
        <Field label="Narx" value={formValues.price} onChange={(value) => setFormValues((prev) => ({ ...prev, price: value }))} />
        <Field label="Rasm manzili" value={formValues.image} onChange={(value) => setFormValues((prev) => ({ ...prev, image: value }))} />
        <div className="grid gap-2">
          <Label htmlFor="course">Kurs</Label>
          <select
            id="course"
            value={formValues.courseId}
            onChange={(event) => setFormValues((prev) => ({ ...prev, courseId: event.target.value }))}
            className="h-11 rounded-xl border border-slate-200 px-3 text-sm outline-none focus:border-primary"
          >
            {courses.map((course) => (
              <option key={course.id} value={course.id}>
                {course.title_uz}
              </option>
            ))}
          </select>
        </div>
        <Button type="submit" className="h-10 rounded-xl px-4 lg:col-span-5">
          Reklamani saqlash
        </Button>
      </form>
      {loading ? <p className="text-sm text-slate-500">Yuklanmoqda...</p> : <AppTable columns={columns} data={ads} emptyText="Reklamalar topilmadi." />}
      <AppModal open={Boolean(editAd)} onOpenChange={(open) => (!open ? setEditAd(null) : undefined)} title="Ad tahrirlash">
        <form
          className="space-y-3"
          onSubmit={async (event) => {
            event.preventDefault();
            if (!editAd) return;
            try {
              const updated = await statusModal.run({
                loadingMessage: "Reklama yangilanmoqda...",
                successMessage: "Reklama muvaffaqiyatli yangilandi",
                errorMessage: "Ad yangilanmadi.",
                action: async () => updateAd(editAd.id, {
                  title: editValues.title,
                  message: editValues.message,
                  price_label: editValues.price,
                  image_url: editValues.image,
                  course_id: editValues.courseId,
                }),
              });
              setAds((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
              setEditAd(null);
              notifySuccess("Ad yangilandi.");
            } catch (error) {
              notifyError(error instanceof Error ? error.message : "Ad yangilanmadi.");
            }
          }}
        >
          <Field label="Sarlavha" value={editValues.title} onChange={(value) => setEditValues((prev) => ({ ...prev, title: value }))} />
          <Field label="Matn" value={editValues.message} onChange={(value) => setEditValues((prev) => ({ ...prev, message: value }))} />
          <Field label="Narx" value={editValues.price} onChange={(value) => setEditValues((prev) => ({ ...prev, price: value }))} />
          <Field label="Rasm manzili" value={editValues.image} onChange={(value) => setEditValues((prev) => ({ ...prev, image: value }))} />
          <Button type="submit" className="h-10 rounded-xl px-4">
            Yangilash
          </Button>
        </form>
      </AppModal>
      <ConfirmDialog
        open={Boolean(deleteAdId)}
        title="Adni o'chirish"
        description="Rostdan ham adni o'chirasizmi?"
        confirmText="Ha, o'chirish"
        onCancel={() => setDeleteAdId(null)}
        onConfirm={async () => {
          if (!deleteAdId) return;
          try {
            await statusModal.run({
              loadingMessage: "Reklama o'chirilmoqda...",
              successMessage: "Muvaffaqiyatli o'chirildi",
              errorMessage: "Adni o'chirishda xatolik.",
              action: async () => removeAd(deleteAdId),
            });
            setAds((prev) => prev.filter((item) => item.id !== deleteAdId));
            notifySuccess("Ad o'chirildi.");
            setDeleteAdId(null);
          } catch (error) {
            notifyError(error instanceof Error ? error.message : "Adni o'chirishda xatolik.");
          }
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}

function Field({ label, value, onChange }: { label: string; value: string; onChange: (value: string) => void }) {
  return (
    <div className="grid gap-2">
      <Label>{label}</Label>
      <Input value={value} onChange={(event) => onChange(event.target.value)} className="h-11 rounded-xl border-slate-200" />
    </div>
  );
}
