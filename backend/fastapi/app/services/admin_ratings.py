from __future__ import annotations

from typing import Any

from supabase import Client

from ..schemas.admin_ratings import AdminRatingItem


def list_admin_ratings(client: Client, *, query: str = "", page: int = 1, page_size: int = 20) -> tuple[list[AdminRatingItem], int]:
    rows = client.table("ratings").select("id,course_id,user_id,stars,created_at").order("created_at", desc=True).execute().data or []
    query_lower = query.strip().lower()
    course_ids = [str(row.get("course_id") or "") for row in rows if row.get("course_id")]
    user_ids = [str(row.get("user_id") or "") for row in rows if row.get("user_id")]

    courses = client.table("courses").select("id,title_uz").in_("id", list(set(course_ids))).execute().data if course_ids else []
    users = client.table("users").select("id,full_name").in_("id", list(set(user_ids))).execute().data if user_ids else []
    course_map = {str(item.get("id") or ""): str(item.get("title_uz") or item.get("id") or "") for item in (courses or [])}
    user_map = {str(item.get("id") or ""): str(item.get("full_name") or "Foydalanuvchi") for item in (users or [])}

    normalized: list[AdminRatingItem] = []
    for row in rows:
        course_id = str(row.get("course_id") or "")
        user_id = str(row.get("user_id") or "")
        entry = AdminRatingItem(
            id=str(row.get("id") or ""),
            course_id=course_id,
            course_title=course_map.get(course_id, course_id),
            user_id=user_id,
            user_name=user_map.get(user_id, "Foydalanuvchi"),
            stars=int(row.get("stars") or 0),
            created_at=str(row.get("created_at") or ""),
        )
        if query_lower and query_lower not in f"{entry.course_title} {entry.user_name} {entry.user_id}".lower():
            continue
        normalized.append(entry)

    total = len(normalized)
    start = max(page - 1, 0) * page_size
    end = start + page_size
    return normalized[start:end], total


def delete_admin_rating(client: Client, *, rating_id: str) -> None:
    client.table("ratings").delete().eq("id", rating_id).execute()


def update_admin_rating(client: Client, *, rating_id: str, stars: int) -> None:
    client.table("ratings").update({"stars": stars}).eq("id", rating_id).execute()


def reset_admin_ratings(client: Client, *, course_id: str | None = None, user_id: str | None = None) -> int:
    query: Any = client.table("ratings").delete()
    if course_id:
        query = query.eq("course_id", course_id)
    if user_id:
        query = query.eq("user_id", user_id)
    response = query.execute()
    return len(response.data or [])
