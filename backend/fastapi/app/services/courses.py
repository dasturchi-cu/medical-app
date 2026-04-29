from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from supabase import Client

from ..schemas.courses import CourseCreate, CourseItem, CourseUpdate

logger = logging.getLogger(__name__)


def _to_item(row: dict[str, Any]) -> CourseItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()

    return CourseItem(
        id=str(row.get("id") or ""),
        title_uz=str(row.get("title_uz") or ""),
        title_ru=str(row.get("title_ru") or ""),
        title_en=str(row.get("title_en") or ""),
        price_uzs=float(row.get("price_uzs") or 0),
        admin_telegram=str(row.get("admin_telegram") or "Neuroscienceadmin"),
        image_url=str(row.get("image_url") or ""),
        is_active=bool(row.get("is_active")),
        views=int(row.get("views") or 0),
        sales=int(row.get("sales") or 0),
        created_at=created,
    )


def list_courses(client: Client, *, active_only: bool = False) -> list[CourseItem]:
    try:
        query = client.table("courses").select("*").order("created_at", desc=True)
        if active_only:
            query = query.eq("is_active", True)
        rows = query.execute().data or []
        return [_to_item(row) for row in rows]
    except Exception as error:
        logger.warning("Failed to list courses from Supabase: %s", error)
        return []


def create_course(client: Client, payload: CourseCreate) -> CourseItem:
    inserted = (
        client.table("courses")
        .insert(
            {
                "title_uz": payload.title_uz.strip(),
                "title_ru": payload.title_ru.strip(),
                "title_en": payload.title_en.strip(),
                "price_uzs": payload.price_uzs,
                "admin_telegram": payload.admin_telegram.replace("@", "").strip() or "Neuroscienceadmin",
                "image_url": payload.image_url.strip(),
            }
        )
        .execute()
    )
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Failed to create course.")
    return _to_item(row)


def update_course(client: Client, *, course_id: str, payload: CourseUpdate) -> CourseItem:
    patch: dict[str, Any] = {}
    for key in ["title_uz", "title_ru", "title_en", "price_uzs", "image_url", "is_active"]:
        value = getattr(payload, key)
        if value is not None:
            patch[key] = value.strip() if isinstance(value, str) else value
    if payload.admin_telegram is not None:
        patch["admin_telegram"] = payload.admin_telegram.replace("@", "").strip() or "Neuroscienceadmin"

    updated = client.table("courses").update(patch).eq("id", course_id).execute()
    row = (updated.data or [None])[0]
    if not row:
        raise RuntimeError("Course not found.")
    return _to_item(row)


def delete_course(client: Client, *, course_id: str) -> None:
    client.table("courses").delete().eq("id", course_id).execute()


def get_course_enrolled_count(client: Client, *, course_id: str) -> int:
    response = (
        client.table("user_entitlements")
        .select("id", count="exact")
        .eq("course_id", course_id)
        .eq("is_active", True)
        .execute()
    )
    return int(response.count or 0)


def get_course_comments_count(client: Client, *, course_id: str) -> int:
    legacy = client.table("comments").select("id", count="exact").eq("course_id", course_id).execute()
    app = client.table("app_comments").select("id", count="exact").eq("course_key", course_id).execute()
    return int(legacy.count or 0) + int(app.count or 0)


def get_course_rating_summary(client: Client, *, course_id: str, user_id: str | None = None) -> tuple[float, int, int | None]:
    rows = client.table("ratings").select("stars,user_id").eq("course_id", course_id).execute().data or []
    if not rows:
        return 0.0, 0, None
    stars = [int(row.get("stars") or 0) for row in rows]
    rating_count = len(stars)
    avg = round(sum(stars) / rating_count, 2) if rating_count > 0 else 0.0
    my_rating = None
    if user_id:
        for row in rows:
            if str(row.get("user_id") or "") == user_id:
                my_rating = int(row.get("stars") or 0)
                break
    return avg, rating_count, my_rating


def upsert_course_rating(client: Client, *, course_id: str, user_id: str, stars: int) -> None:
    existing = (
        client.table("ratings")
        .select("id")
        .eq("course_id", course_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    ).data or []
    if existing:
        client.table("ratings").update({"stars": stars}).eq("course_id", course_id).eq("user_id", user_id).execute()
    else:
        client.table("ratings").insert({"course_id": course_id, "user_id": user_id, "stars": stars}).execute()
