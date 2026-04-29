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
import { createBanner, fetchBanners, removeBanner, updateBanner, type BannerItem } from "@/lib/api/banners";
import { notifyError, notifySuccess } from "@/lib/notify";

const DEFAULT_ADMIN_TELEGRAM = "Neuroscienceadmin";

export default function BannersPage() {
  const [banners, setBanners] = useState<BannerItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [editBanner, setEditBanner] = useState<BannerItem | null>(null);
  const [deleteBannerId, setDeleteBannerId] = useState<string | null>(null);
  const [formValues, setFormValues] = useState({
    title: "",
    message: "",
    price: "",
    image: "",
  });
  const [editValues, setEditValues] = useState({
    title: "",
    message: "",
    price: "",
    image: "",
  });

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const bannerItems = await fetchBanners();
        if (!mounted) return;
        setBanners(bannerItems);
      } catch (error) {
        if (!mounted) return;
        notifyError(error instanceof Error ? error.message : "Reklamalarni olishda xatolik.");
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
      {
        key: "preview",
        label: "Ko'rinish",
        render: (item: BannerItem) =>
          item.image_url ? (
            <div
              className="h-12 w-20 rounded-xl bg-cover bg-center"
              style={{ backgroundImage: `url(${item.image_url})` }}
            />
          ) : (
            <BlueBanner />
          ),
      },
      { key: "title", label: "Reklama nomi" },
      {
        key: "message",
        label: "Nima haqida",
        render: (item: BannerItem) => <span className="line-clamp-2 max-w-[220px]">{item.message}</span>,
      },
      { key: "price", label: "Narx", render: (item: BannerItem) => item.price_label || "Kelishiladi" },
      {
        key: "actions",
        label: "Amallar",
        render: (item: BannerItem) => {
          return (
            <div className="flex flex-wrap gap-2">
              <Button
                variant="outline"
                className="h-8 rounded-lg border-slate-200 px-3 text-xs"
                onClick={() => {
                  setEditBanner(item);
                  setEditValues({
                    title: item.title,
                    message: item.message,
                    price: item.price_label,
                    image: item.image_url,
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
    [],
  );

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    try {
      const created = await createBanner({
        title: formValues.title.trim(),
        message: formValues.message.trim(),
        price_label: formValues.price.trim() || "Kelishiladi",
        telegram: DEFAULT_ADMIN_TELEGRAM,
        image_url: formValues.image.trim(),
        course_id: null,
      });
      setBanners((prev) => [created, ...prev]);
      notifySuccess("Kurs reklamasi muvaffaqiyatli qo'shildi.");
      setFormValues({
        title: "",
        message: "",
        price: "",
        image: "",
      });
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Kurs reklamasi qo'shilmadi.");
    }
  };

  const onEditSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editBanner) return;
    try {
      const updated = await updateBanner(editBanner.id, {
        title: editValues.title.trim(),
        message: editValues.message.trim(),
        price_label: editValues.price.trim() || "Kelishiladi",
        telegram: DEFAULT_ADMIN_TELEGRAM,
        image_url: editValues.image ?? "",
        course_id: null,
      });
      setBanners((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
      notifySuccess("Kurs reklamasi muvaffaqiyatli yangilandi.");
      setEditBanner(null);
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Kurs reklamasi yangilanmadi.");
    }
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <AppForm title="Kurs reklamasi yaratish" description="Reklama orqali foydalanuvchi onlayn kursga qiziqadi." onSubmit={onSubmit}>
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
        <ImagePicker
          label="Rasm (upload yoki link)"
          value={formValues.image}
          helperText="Rasm qo&apos;yilmasa, avtomatik ko&apos;k banner ishlatiladi."
          onChange={(value) => setFormValues((prev) => ({ ...prev, image: value }))}
        />
      </AppForm>

      <AppTable columns={columns} data={banners} emptyText="Hali reklama qo'shilmagan." />

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
          <ImagePicker
            label="Rasm (upload yoki link)"
            value={editValues.image ?? ""}
            helperText="Rasm qo&apos;yilmasa, avtomatik ko&apos;k banner ishlatiladi."
            onChange={(value) => setEditValues((prev) => ({ ...prev, image: value }))}
          />
        </AppForm>
      </AppModal>

      <ConfirmDialog
        open={Boolean(deleteBannerId)}
        title="Reklamani o&apos;chirish"
        description="Rostdan ham ushbu reklamani o&apos;chirmoqchimisiz?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteBannerId(null)}
        onConfirm={async () => {
          if (!deleteBannerId) return;
          try {
            await removeBanner(deleteBannerId);
            setBanners((prev) => prev.filter((item) => item.id !== deleteBannerId));
            notifySuccess("Kurs reklamasi muvaffaqiyatli o'chirildi.");
            setDeleteBannerId(null);
          } catch (error) {
            notifyError(error instanceof Error ? error.message : "Kurs reklamasi o'chirilmadi.");
          }
        }}
      />
    </section>
  );
}

