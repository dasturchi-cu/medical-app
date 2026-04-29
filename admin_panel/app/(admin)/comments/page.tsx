"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { Heart, MessageCircle } from "lucide-react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { PageSkeleton } from "@/components/page-skeleton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { adminActions, courseTitleByLanguage, useAdminStore } from "@/lib/admin-store";

export default function CommentsPage() {
  const { comments, users, courses } = useAdminStore((state) => state);
  const [loading, setLoading] = useState(true);
  const [deleteCommentId, setDeleteCommentId] = useState<string | null>(null);
  const [replyOpenId, setReplyOpenId] = useState<string | null>(null);
  const [replyValues, setReplyValues] = useState<Record<string, string>>({});

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const commentThreads = useMemo(
    () =>
      comments
        .filter((item) => item.parent_id === null)
        .map((item) => ({
          root: item,
          replies: comments.filter((reply) => reply.parent_id === item.id),
        })),
    [comments],
  );

  if (loading) return <PageSkeleton />;

  return (
    <section className="space-y-4">
      <div className="surface-card space-y-2 p-5">
        <h3 className="text-lg font-semibold text-slate-900">Izohlar va javoblar</h3>
        <p className="text-sm text-slate-500">
          YouTube uslubida kommentga yurakcha bosing, javob yozing va foydalanuvchi profiliga o&apos;ting.
        </p>
      </div>

      <div className="surface-card space-y-4 p-4 sm:p-5">
        {commentThreads.length > 0 ? (
          commentThreads.map(({ root, replies }) => {
            const rootUser = users.find((user) => user.id === root.user_id);
            const course = courses.find((entry) => entry.id === root.course_id);
            const isReplyOpen = replyOpenId === root.id;
            const replyValue = replyValues[root.id] ?? "";
            return (
              <article key={root.id} className="rounded-2xl border border-slate-100 bg-white p-4">
                <CommentRow
                  username={rootUser?.name ?? root.user_id}
                  userId={root.user_id}
                  isAdmin={root.user_id === "admin"}
                  courseName={course ? courseTitleByLanguage(course, "uz") : root.course_id}
                  text={root.text}
                  date={root.created_at}
                  hearts={root.hearts}
                  hearted={root.hearted_by_admin}
                  onHeart={() => adminActions.toggleCommentHeart(root.id)}
                  onReply={() => setReplyOpenId((prev) => (prev === root.id ? null : root.id))}
                  onDelete={() => setDeleteCommentId(root.id)}
                />

                {replies.length > 0 ? (
                  <div className="mt-3 space-y-3 border-l-2 border-slate-100 pl-4">
                    {replies.map((reply) => {
                      const replyUser = users.find((user) => user.id === reply.user_id);
                      return (
                        <CommentRow
                          key={reply.id}
                          username={reply.user_id === "admin" ? "Admin" : (replyUser?.name ?? reply.user_id)}
                          userId={reply.user_id}
                          isAdmin={reply.user_id === "admin"}
                          courseName={course ? courseTitleByLanguage(course, "uz") : reply.course_id}
                          text={reply.text}
                          date={reply.created_at}
                          hearts={reply.hearts}
                          hearted={reply.hearted_by_admin}
                          onHeart={() => adminActions.toggleCommentHeart(reply.id)}
                          onReply={() => setReplyOpenId(root.id)}
                          onDelete={() => setDeleteCommentId(reply.id)}
                        />
                      );
                    })}
                  </div>
                ) : null}

                {isReplyOpen ? (
                  <div className="mt-3 flex flex-wrap items-center gap-2 border-l-2 border-slate-100 pl-4">
                    <Input
                      value={replyValue}
                      onChange={(event) =>
                        setReplyValues((prev) => ({ ...prev, [root.id]: event.target.value }))
                      }
                      placeholder="Admin javobi..."
                      className="h-10 w-full flex-1 rounded-xl border-slate-200 sm:min-w-[240px]"
                    />
                    <Button
                      className="h-10 rounded-xl px-4"
                      onClick={() => {
                        adminActions.addCommentReply({
                          parentId: root.id,
                          courseId: root.course_id,
                          text: replyValue,
                        });
                        setReplyValues((prev) => ({ ...prev, [root.id]: "" }));
                        setReplyOpenId(null);
                      }}
                    >
                      Javob yuborish
                    </Button>
                  </div>
                ) : null}
              </article>
            );
          })
        ) : (
          <p className="text-sm text-slate-400">Hali izohlar yozilmagan.</p>
        )}
      </div>

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

interface CommentRowProps {
  username: string;
  userId: string;
  isAdmin: boolean;
  courseName: string;
  text: string;
  date: string;
  hearts: number;
  hearted: boolean;
  onHeart: () => void;
  onReply: () => void;
  onDelete: () => void;
}

function CommentRow({
  username,
  userId,
  isAdmin,
  courseName,
  text,
  date,
  hearts,
  hearted,
  onHeart,
  onReply,
  onDelete,
}: CommentRowProps) {
  return (
    <div className="flex items-start justify-between gap-3">
      <div className="min-w-0 flex-1">
        <div className="mb-2 flex items-center gap-2">
          <div className="inline-flex size-9 items-center justify-center rounded-full bg-[#eff4ff] text-xs font-semibold text-primary">
            {username.slice(0, 1).toUpperCase()}
          </div>
          {isAdmin ? (
            <span className="text-sm font-semibold text-slate-800">Admin</span>
          ) : (
            <Link href={`/users/${userId}`} className="text-sm font-semibold text-slate-800 hover:text-primary">
              {username}
            </Link>
          )}
          <span className="rounded-lg bg-slate-50 px-2 py-1 text-xs text-slate-500">{courseName}</span>
          <span className="text-xs text-slate-400">{date}</span>
        </div>
        <p className="text-sm leading-6 text-slate-700">{text}</p>
        <div className="mt-2 flex items-center gap-2">
          <Button
            variant={hearted ? "destructive" : "ghost"}
            size="sm"
            className="h-8 rounded-lg px-2 text-xs"
            onClick={onHeart}
          >
            <Heart className="size-3.5" />
            {hearts}
          </Button>
          <Button variant="ghost" size="sm" className="h-8 rounded-lg px-2 text-xs" onClick={onReply}>
            <MessageCircle className="size-3.5" />
            Javob yozish
          </Button>
        </div>
      </div>
      <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={onDelete}>
        O&apos;chirish
      </Button>
    </div>
  );
}
