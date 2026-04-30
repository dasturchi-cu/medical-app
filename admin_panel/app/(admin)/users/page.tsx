"use client";

import Link from "next/link";
import { type FormEvent, useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppModal } from "@/components/modal";
import { PageSkeleton } from "@/components/page-skeleton";
import { StatusModal } from "@/components/status-modal";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { fetchCourses } from "@/lib/api/courses";
import { blockUser, fetchUsers, grantCourse, removeUser, type AdminUserItem, unblockUser, updateUser } from "@/lib/api/users";
import { notifyError, notifySuccess } from "@/lib/notify";
import { useStatusModal } from "@/lib/use-status-modal";

export default function UsersPage() {
  const [users, setUsers] = useState<AdminUserItem[]>([]);
  const [courses, setCourses] = useState<Array<{ id: string; title_uz: string }>>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [selectedCourse, setSelectedCourse] = useState("");
  const [page, setPage] = useState(1);
  const pageSize = 8;
  const [editUser, setEditUser] = useState<AdminUserItem | null>(null);
  const [deleteUserId, setDeleteUserId] = useState<string | null>(null);
  const [editValues, setEditValues] = useState({ name: "", email: "" });
  const statusModal = useStatusModal();
  const runStatus = statusModal.run;

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const [usersItems, coursesItems] = await Promise.all([fetchUsers(), fetchCourses()]);
        if (!mounted) return;
        setUsers(usersItems);
        setCourses(coursesItems.map((item) => ({ id: item.id, title_uz: item.title_uz })));
        setSelectedCourse(coursesItems[0]?.id ?? "");
      } catch (error) {
        if (!mounted) return;
        notifyError(error instanceof Error ? error.message : "Foydalanuvchilarni olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    return () => {
      mounted = false;
    };
  }, []);

  const filteredUsers = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return users;
    return users.filter(
      (user) =>
        user.id.toLowerCase().includes(q) || user.name.toLowerCase().includes(q) || user.email.toLowerCase().includes(q),
    );
  }, [query, users]);
  const pageCount = Math.max(1, Math.ceil(filteredUsers.length / pageSize));
  const pageUsers = filteredUsers.slice((page - 1) * pageSize, page * pageSize);

  const columns = useMemo(
    () => [
      {
        key: "name",
        label: "Foydalanuvchi",
        render: (user: AdminUserItem) => (
          <Link href={`/users/${user.id}`} className="text-primary hover:underline">
            {user.name}
          </Link>
        ),
      },
      { key: "id", label: "Foydalanuvchi ID" },
      { key: "email", label: "Email" },
      { key: "login_count", label: "Login soni" },
      { key: "app_open_count", label: "App open soni" },
      {
        key: "is_blocked",
        label: "Holat",
        render: (user: AdminUserItem) =>
          user.is_blocked ? (
            <span className="rounded-lg bg-red-50 px-2 py-1 text-xs text-red-600">Bloklangan</span>
          ) : (
            <span className="rounded-lg bg-emerald-50 px-2 py-1 text-xs text-emerald-600">Faol</span>
          ),
      },
      {
        key: "actions",
        label: "Amallar",
        render: (user: AdminUserItem) => (
          <div className="flex flex-wrap gap-2">
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs"
              onClick={() => {
                setEditUser(user);
                setEditValues({ name: user.name, email: user.email });
              }}
            >
              Tahrirlash
            </Button>
            <Button
              variant="destructive"
              className="h-8 rounded-lg px-3 text-xs"
              onClick={async () => {
                try {
                  await runStatus({
                    loadingMessage: "Foydalanuvchi bloklanmoqda...",
                    successMessage: "Foydalanuvchi muvaffaqiyatli bloklandi",
                    errorMessage: "Bloklashda xatolik.",
                    action: async () => blockUser(user.id),
                  });
                  setUsers((prev) => prev.map((u) => (u.id === user.id ? { ...u, is_blocked: true } : u)));
                  notifySuccess("Foydalanuvchi bloklandi.");
                } catch (error) {
                  notifyError(error instanceof Error ? error.message : "Bloklashda xatolik.");
                }
              }}
              disabled={user.is_blocked}
            >
              Bloklash
            </Button>
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs"
              onClick={async () => {
                try {
                  await runStatus({
                    loadingMessage: "Foydalanuvchi blokdan chiqarilmoqda...",
                    successMessage: "Foydalanuvchi muvaffaqiyatli blokdan chiqarildi",
                    errorMessage: "Unblockda xatolik.",
                    action: async () => unblockUser(user.id),
                  });
                  setUsers((prev) => prev.map((u) => (u.id === user.id ? { ...u, is_blocked: false } : u)));
                  notifySuccess("Foydalanuvchi blokdan chiqarildi.");
                } catch (error) {
                  notifyError(error instanceof Error ? error.message : "Unblockda xatolik.");
                }
              }}
              disabled={!user.is_blocked}
            >
              Blokdan chiqarish
            </Button>
            <Button
              className="h-8 rounded-lg bg-primary px-3 text-xs text-white"
              onClick={async () => {
                if (!selectedCourse) {
                  notifyError("Avval kurs tanlang.");
                  return;
                }
                try {
                  await runStatus({
                    loadingMessage: "Kurs biriktirilmoqda...",
                    successMessage: "Kurs muvaffaqiyatli biriktirildi",
                    errorMessage: "Kurs berishda xatolik.",
                    action: async () => grantCourse(user.id, selectedCourse),
                  });
                  notifySuccess("Foydalanuvchiga kurs muvaffaqiyatli berildi.");
                } catch (error) {
                  notifyError(error instanceof Error ? error.message : "Kurs berishda xatolik.");
                }
              }}
            >
              Kurs berish
            </Button>
            <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteUserId(user.id)}>
              O&apos;chirish
            </Button>
          </div>
        ),
      },
    ],
    [selectedCourse, runStatus],
  );

  const onEditSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editUser) return;
    try {
      const updated = await runStatus({
        loadingMessage: "Foydalanuvchi saqlanmoqda...",
        successMessage: "Foydalanuvchi muvaffaqiyatli yangilandi",
        errorMessage: "Foydalanuvchini yangilab bo'lmadi.",
        action: async () => updateUser(editUser.id, {
          name: editValues.name.trim(),
          email: editValues.email.trim(),
        }),
      });
      setUsers((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
      notifySuccess("Foydalanuvchi muvaffaqiyatli yangilandi.");
      setEditUser(null);
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Foydalanuvchini yangilab bo'lmadi.");
    }
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <div className="space-y-4">
        <div className="surface-card p-4">
          <label htmlFor="search-user" className="mb-2 block text-sm font-medium text-slate-700">
            Foydalanuvchi qidirish
          </label>
          <Input
            id="search-user"
            value={query}
            onChange={(event) => {
              setQuery(event.target.value);
              setPage(1);
            }}
            placeholder="ID, ism yoki email bo'yicha qidiring"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>

        <div className="surface-card grid gap-3 p-4">
          <div>
            <label className="mb-2 block text-sm font-medium text-slate-700">Qaysi kurs beriladi?</label>
            <select
              value={selectedCourse}
              onChange={(event) => setSelectedCourse(event.target.value)}
              className="h-11 w-full rounded-xl border border-slate-200 px-3 text-sm outline-none focus:border-primary"
            >
              {courses.map((course) => (
                <option key={course.id} value={course.id}>
                  {course.title_uz}
                </option>
              ))}
            </select>
          </div>
        </div>

        <AppTable columns={columns} data={pageUsers} emptyText="Foydalanuvchi topilmadi." />
        <div className="flex items-center justify-between text-sm text-slate-500">
          <p>
            Jami: {filteredUsers.length} | Sahifa: {page}/{pageCount}
          </p>
          <div className="flex gap-2">
            <Button variant="outline" className="h-8 rounded-lg px-3 text-xs" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
              Oldingi
            </Button>
            <Button
              variant="outline"
              className="h-8 rounded-lg px-3 text-xs"
              disabled={page >= pageCount}
              onClick={() => setPage((p) => p + 1)}
            >
              Keyingi
            </Button>
          </div>
        </div>
      </div>

      <AppModal open={Boolean(editUser)} onOpenChange={(open) => (!open ? setEditUser(null) : undefined)} title="Foydalanuvchini tahrirlash">
        <form className="space-y-3" onSubmit={onEditSubmit}>
          <div className="grid gap-2">
            <Label htmlFor="edit_name">Ism</Label>
            <Input
              id="edit_name"
              value={editValues.name}
              onChange={(event) => setEditValues((prev) => ({ ...prev, name: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit_email">Email / phone</Label>
            <Input
              id="edit_email"
              value={editValues.email}
              onChange={(event) => setEditValues((prev) => ({ ...prev, email: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <Button type="submit" className="h-10 rounded-xl px-4">
            Saqlash
          </Button>
        </form>
      </AppModal>
      <ConfirmDialog
        open={Boolean(deleteUserId)}
        title="Foydalanuvchini o'chirish"
        description="Bu amal ortga qaytarilmaydi. Davom etasizmi?"
        confirmText="Ha, o'chirish"
        onCancel={() => setDeleteUserId(null)}
        onConfirm={async () => {
          if (!deleteUserId) return;
          try {
            await runStatus({
              loadingMessage: "Foydalanuvchi o'chirilmoqda...",
              successMessage: "Muvaffaqiyatli o'chirildi",
              errorMessage: "Foydalanuvchini o'chirishda xatolik.",
              action: async () => removeUser(deleteUserId),
            });
            setUsers((prev) => prev.filter((item) => item.id !== deleteUserId));
            notifySuccess("Foydalanuvchi o'chirildi.");
            setDeleteUserId(null);
          } catch (error) {
            notifyError(error instanceof Error ? error.message : "Foydalanuvchini o'chirishda xatolik.");
          }
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}
