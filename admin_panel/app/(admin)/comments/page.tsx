"use client";

import { useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { PageSkeleton } from "@/components/page-skeleton";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { adminActions, courseTitleByLanguage, useAdminStore } from "@/lib/admin-store";

export default function CommentsPage() {
  const { comments, ratings, users, courses } = useAdminStore((state) => state);
  const [loading, setLoading] = useState(true);
  const [deleteCommentId, setDeleteCommentId] = useState<string | null>(null);

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const columns = useMemo(
    () => [
      {
        key: "courseId",
        label: "Kurs",
        render: (item: (typeof comments)[number]) => {
          const course = courses.find((entry) => entry.id === item.course_id);
          return <span>{course ? courseTitleByLanguage(course, "uz") : item.course_id}</span>;
        },
      },
      {
        key: "userId",
        label: "Foydalanuvchi",
        render: (item: (typeof comments)[number]) => users.find((user) => user.id === item.user_id)?.name ?? item.user_id,
      },
      { key: "text", label: "Izoh" },
      {
        key: "rating",
        label: "Reyting",
        render: (item: (typeof comments)[number]) => {
          const rating = ratings.find(
            (entry) => entry.user_id === item.user_id && entry.course_id === item.course_id,
          );
          return rating ? "⭐".repeat(rating.rating) : "-";
        },
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: (typeof comments)[number]) => (
          <Button
            variant="destructive"
            className="h-8 rounded-lg px-3 text-xs"
            onClick={() => setDeleteCommentId(item.id)}
          >
            O&apos;chirish
          </Button>
        ),
      },
    ],
    [courses, ratings, users],
  );

  if (loading) return <PageSkeleton />;

  return (
    <section className="space-y-4">
      <AppTable columns={columns} data={comments} emptyText="Hali izohlar yozilmagan." />
      <ConfirmDialog
        open={Boolean(deleteCommentId)}
        title="Izohni o&apos;chirish"
        description="Rostdan ham ushbu izohni o&apos;chirmoqchimisiz?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteCommentId(null)}
        onConfirm={() => {
          if (!deleteCommentId) return;
          adminActions.deleteComment(deleteCommentId);
          setDeleteCommentId(null);
        }}
      />
    </section>
  );
}
