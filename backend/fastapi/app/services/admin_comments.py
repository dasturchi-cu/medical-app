from __future__ import annotations

from datetime import datetime
from typing import Any

from supabase import Client

from ..schemas.admin_comments import AdminCommentItem


def _resolve_admin_actor(client: Client, configured_admin_user_id: str | None) -> str:
    configured = (configured_admin_user_id or "").strip()
    if configured:
        exists = client.table("users").select("id").eq("id", configured).limit(1).execute().data or []
        if exists:
            return configured
    first_user = client.table("users").select("id").order("created_at", desc=False).limit(1).execute().data or []
    if not first_user:
        raise RuntimeError("Admin amallar uchun users jadvalida hech bo'lmasa bitta user kerak.")
    return str(first_user[0].get("id") or "")


def list_admin_comments(client: Client, *, configured_admin_user_id: str | None = None) -> list[AdminCommentItem]:
    comments = client.table("comments").select("*").order("created_at", desc=True).limit(500).execute().data or []
    if not comments:
        return []
    user_ids = list({str(row.get("user_id")) for row in comments if row.get("user_id")})
    users = client.table("users").select("id,full_name,phone").in_("id", user_ids).execute().data if user_ids else []
    user_map = {
        str(row.get("id")): str(row.get("full_name") or row.get("phone") or row.get("id") or "")
        for row in (users or [])
    }

    admin_user_id = _resolve_admin_actor(client, configured_admin_user_id)
    comment_ids = [str(row.get("id")) for row in comments if row.get("id")]
    admin_reactions = (
        client.table("comment_reactions")
        .select("comment_id")
        .eq("user_id", admin_user_id)
        .in_("comment_id", comment_ids)
        .execute()
    ).data or []
    liked = {str(row.get("comment_id")) for row in admin_reactions}

    items: list[AdminCommentItem] = []
    for row in comments:
        items.append(
            AdminCommentItem(
                id=str(row.get("id") or ""),
                course_id=str(row.get("course_id") or ""),
                user_id=str(row.get("user_id") or ""),
                user_name=user_map.get(str(row.get("user_id") or ""), str(row.get("user_id") or "")),
                text=str(row.get("text") or ""),
                hearts=int(row.get("hearts_count") or 0),
                parent_id=str(row.get("parent_id")) if row.get("parent_id") else None,
                created_at=str(row.get("created_at") or ""),
                hearted_by_admin=str(row.get("id") or "") in liked,
            )
        )
    return items


def add_admin_reply(client: Client, *, comment_id: str, text: str, configured_admin_user_id: str | None = None) -> AdminCommentItem:
    parent = client.table("comments").select("*").eq("id", comment_id).limit(1).execute().data or []
    if not parent:
        raise RuntimeError("Izoh topilmadi.")
    parent_row = parent[0]
    admin_user_id = _resolve_admin_actor(client, configured_admin_user_id)
    inserted = (
        client.table("comments")
        .insert(
            {
                "course_id": parent_row.get("course_id"),
                "user_id": admin_user_id,
                "parent_id": comment_id,
                "text": text.strip(),
                "hearts_count": 0,
            }
        )
        .execute()
    ).data or []
    if not inserted:
        raise RuntimeError("Javob qo'shib bo'lmadi.")
    item = inserted[0]
    user_name = client.table("users").select("full_name,phone").eq("id", admin_user_id).limit(1).execute().data or []
    author = str((user_name[0].get("full_name") if user_name else "") or (user_name[0].get("phone") if user_name else "") or "Admin")
    return AdminCommentItem(
        id=str(item.get("id") or ""),
        course_id=str(item.get("course_id") or ""),
        user_id=admin_user_id,
        user_name=author,
        text=str(item.get("text") or ""),
        hearts=0,
        parent_id=str(item.get("parent_id") or ""),
        created_at=str(item.get("created_at") or datetime.utcnow().isoformat()),
        hearted_by_admin=False,
    )


def toggle_admin_heart(client: Client, *, comment_id: str, configured_admin_user_id: str | None = None) -> AdminCommentItem:
    comment_rows = client.table("comments").select("*").eq("id", comment_id).limit(1).execute().data or []
    if not comment_rows:
        raise RuntimeError("Izoh topilmadi.")
    comment = comment_rows[0]
    admin_user_id = _resolve_admin_actor(client, configured_admin_user_id)
    existing = (
        client.table("comment_reactions")
        .select("id")
        .eq("comment_id", comment_id)
        .eq("user_id", admin_user_id)
        .limit(1)
        .execute()
    ).data or []
    if existing:
        client.table("comment_reactions").delete().eq("comment_id", comment_id).eq("user_id", admin_user_id).execute()
        delta = -1
        hearted = False
    else:
        client.table("comment_reactions").insert({"comment_id": comment_id, "user_id": admin_user_id}).execute()
        delta = 1
        hearted = True

    next_hearts = max(0, int(comment.get("hearts_count") or 0) + delta)
    updated = client.table("comments").update({"hearts_count": next_hearts}).eq("id", comment_id).execute().data or [comment]
    row = updated[0]
    author = client.table("users").select("full_name,phone").eq("id", row.get("user_id")).limit(1).execute().data or []
    name = str((author[0].get("full_name") if author else "") or (author[0].get("phone") if author else "") or row.get("user_id") or "")
    return AdminCommentItem(
        id=str(row.get("id") or ""),
        course_id=str(row.get("course_id") or ""),
        user_id=str(row.get("user_id") or ""),
        user_name=name,
        text=str(row.get("text") or ""),
        hearts=int(row.get("hearts_count") or 0),
        parent_id=str(row.get("parent_id")) if row.get("parent_id") else None,
        created_at=str(row.get("created_at") or ""),
        hearted_by_admin=hearted,
    )


def delete_admin_comment(client: Client, *, comment_id: str) -> None:
    client.table("comments").delete().eq("id", comment_id).execute()
