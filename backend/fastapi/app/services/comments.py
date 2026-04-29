from __future__ import annotations

from datetime import datetime
from typing import Any

from supabase import Client

from ..schemas.comments import AppCommentItem, AddCommentRequest


def _to_item(row: dict[str, Any], *, liked_by_me: bool) -> AppCommentItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return AppCommentItem(
        id=str(row.get("id") or ""),
        course_key=str(row.get("course_key") or ""),
        user_id=str(row.get("user_id") or ""),
        author_name=str(row.get("author_name") or ""),
        text=str(row.get("text") or ""),
        likes_count=int(row.get("likes_count") or 0),
        liked_by_me=liked_by_me,
        created_at=created,
    )


def list_comments(client: Client, *, course_key: str, user_id: str | None = None) -> list[AppCommentItem]:
    rows = (
        client.table("app_comments")
        .select("*")
        .eq("course_key", course_key)
        .order("created_at", desc=True)
        .limit(200)
        .execute()
    ).data or []
    if not rows:
        return []

    liked_ids: set[str] = set()
    if user_id:
        comment_ids = [row["id"] for row in rows]
        likes = (
            client.table("app_comment_likes")
            .select("comment_id")
            .eq("user_id", user_id)
            .in_("comment_id", comment_ids)
            .execute()
        ).data or []
        liked_ids = {str(row.get("comment_id")) for row in likes}

    return [_to_item(row, liked_by_me=str(row.get("id")) in liked_ids) for row in rows]


def add_comment(client: Client, payload: AddCommentRequest) -> AppCommentItem:
    inserted = (
        client.table("app_comments")
        .insert(
            {
                "course_key": payload.course_key,
                "user_id": payload.user_id,
                "author_name": payload.author_name.strip(),
                "text": payload.text.strip(),
            }
        )
        .execute()
    )
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Failed to add comment.")
    return _to_item(row, liked_by_me=False)


def toggle_like(client: Client, *, comment_id: str, user_id: str) -> AppCommentItem:
    existing = (
        client.table("app_comment_likes")
        .select("id")
        .eq("comment_id", comment_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    ).data or []

    if existing:
        client.table("app_comment_likes").delete().eq("comment_id", comment_id).eq("user_id", user_id).execute()
        delta = -1
        liked = False
    else:
        client.table("app_comment_likes").insert({"comment_id": comment_id, "user_id": user_id}).execute()
        delta = 1
        liked = True

    row_resp = client.table("app_comments").select("*").eq("id", comment_id).limit(1).execute()
    row = (row_resp.data or [None])[0]
    if not row:
        raise RuntimeError("Comment not found.")

    next_likes = max(0, int(row.get("likes_count") or 0) + delta)
    updated = client.table("app_comments").update({"likes_count": next_likes}).eq("id", comment_id).execute()
    updated_row = (updated.data or [row])[0]
    return _to_item(updated_row, liked_by_me=liked)
