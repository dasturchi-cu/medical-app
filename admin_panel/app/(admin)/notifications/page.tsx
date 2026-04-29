"use client";

import { type FormEvent, useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { ImagePicker } from "@/components/image-picker";
import { PageSkeleton } from "@/components/page-skeleton";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { adminActions, type NotificationCampaign, useAdminStore } from "@/lib/admin-store";
import { notifySuccess } from "@/lib/notify";

export default function NotificationsPage() {
  const { notifications, users } = useAdminStore((state) => state);
  const [loading, setLoading] = useState(true);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [formValues, setFormValues] = useState({
    title: "",
    message: "",
    image: "",
  });

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 450);
    return () => clearTimeout(timer);
  }, []);

  const stats = useMemo(() => {
    const totalSent = notifications.reduce((sum, item) => sum + item.recipients_count, 0);
    const totalViewed = notifications.reduce((sum, item) => sum + item.viewed_count, 0);
    const avgViewRate = totalSent > 0 ? (totalViewed / totalSent) * 100 : 0;
    return {
      totalUsers: users.length,
      sentCampaigns: notifications.length,
      totalSent,
      avgViewRate,
    };
  }, [notifications, users.length]);

  const columns = useMemo(
    () => [
      { key: "title", label: "Sarlavha" },
      {
        key: "message",
        label: "Matn",
        render: (item: NotificationCampaign) => <span className="line-clamp-2 max-w-[300px]">{item.message}</span>,
      },
      { key: "recipients_count", label: "Yuborildi" },
      { key: "viewed_count", label: "Ko'rganlar" },
      {
        key: "viewRate",
        label: "Ko'rish foizi",
        render: (item: NotificationCampaign) => {
          const rate = item.recipients_count > 0 ? (item.viewed_count / item.recipients_count) * 100 : 0;
          return `${rate.toFixed(1)}%`;
        },
      },
      { key: "sent_at", label: "Vaqt" },
      {
        key: "actions",
        label: "Amallar",
        render: (item: NotificationCampaign) => (
          <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteId(item.id)}>
            O&apos;chirish
          </Button>
        ),
      },
    ],
    [],
  );

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    adminActions.sendNotification({
      title: formValues.title,
      message: formValues.message,
      image: formValues.image,
    });
    notifySuccess("Notification muvaffaqiyatli yuborildi.");
    setFormValues({ title: "", message: "", image: "" });
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Jami foydalanuvchi" value={String(stats.totalUsers)} />
        <StatCard label="Yuborilgan kampaniya" value={String(stats.sentCampaigns)} />
        <StatCard label="Jami yuborilgan notification" value={String(stats.totalSent)} />
        <StatCard label="O'rtacha ko'rish foizi" value={`${stats.avgViewRate.toFixed(1)}%`} />
      </div>

      <AppForm
        title="Notification yuborish"
        description="Barcha foydalanuvchilarga xabar yuboring. Rasm ham qo&apos;shishingiz mumkin."
        onSubmit={onSubmit}
        submitLabel="Yuborish"
      >
        <div className="grid gap-2">
          <Label htmlFor="title">Sarlavha</Label>
          <Input
            id="title"
            value={formValues.title}
            onChange={(event) => setFormValues((prev) => ({ ...prev, title: event.target.value }))}
            placeholder="Masalan: Yangi darslar chiqdi"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="message">Xabar matni</Label>
          <Input
            id="message"
            value={formValues.message}
            onChange={(event) => setFormValues((prev) => ({ ...prev, message: event.target.value }))}
            placeholder="Masalan: Ilovaga kirib yangi darslarni ko'ring"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>
        <ImagePicker
          label="Notification rasmi (ixtiyoriy)"
          value={formValues.image}
          helperText="Rasm tanlansa, notification bilan birga yuboriladi."
          onChange={(value) => setFormValues((prev) => ({ ...prev, image: value }))}
        />
      </AppForm>

      <AppTable columns={columns} data={notifications} emptyText="Hali notification yuborilmagan." />

      <ConfirmDialog
        open={Boolean(deleteId)}
        title="Notificationni o&apos;chirish"
        description="Rostdan ham ushbu notification tarixini o&apos;chirmoqchimisiz?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteId(null)}
        onConfirm={() => {
          if (!deleteId) return;
          adminActions.deleteNotification(deleteId);
          notifySuccess("Notification tarixi o'chirildi.");
          setDeleteId(null);
        }}
      />
    </section>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="surface-card p-4">
      <p className="text-sm text-slate-500">{label}</p>
      <p className="mt-2 text-2xl font-semibold text-slate-900">{value}</p>
    </div>
  );
}
