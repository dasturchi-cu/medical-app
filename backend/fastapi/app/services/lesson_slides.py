from __future__ import annotations

from datetime import datetime
from typing import Any

from supabase import Client

from ..schemas.lesson_slides import LessonSlideCreate, LessonSlideItem, LessonSlideUpdate


def _to_item(row: dict[str, Any]) -> LessonSlideItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return LessonSlideItem(
        id=str(row.get("id") or ""),
        lesson_id=str(row.get("lesson_id") or ""),
        title=str(row.get("title") or ""),
        body=str(row.get("body") or ""),
        image_url=str(row.get("image_url") or ""),
        order_no=int(row.get("order_no") or 1),
        is_active=bool(row.get("is_active")),
        created_at=created,
    )


def list_lesson_slides(client: Client, *, lesson_id: str, active_only: bool = True) -> list[LessonSlideItem]:
    query = client.table("lesson_slides").select("*").eq("lesson_id", lesson_id).order("order_no", desc=False)
    if active_only:
        query = query.eq("is_active", True)
    response = query.execute()
    return [_to_item(row) for row in (response.data or [])]


def create_lesson_slide(client: Client, payload: LessonSlideCreate) -> LessonSlideItem:
    inserted = (
        client.table("lesson_slides")
        .insert(
            {
                "lesson_id": payload.lesson_id,
                "title": payload.title.strip(),
                "body": payload.body.strip(),
                "image_url": payload.image_url.strip(),
                "order_no": payload.order_no,
            }
        )
        .execute()
    )
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Failed to create lesson slide.")
    return _to_item(row)


def update_lesson_slide(client: Client, *, slide_id: str, payload: LessonSlideUpdate) -> LessonSlideItem:
    patch: dict[str, Any] = {}
    for key in ["title", "body", "image_url", "order_no", "is_active"]:
        value = getattr(payload, key)
        if value is not None:
            patch[key] = value.strip() if isinstance(value, str) else value
    updated = client.table("lesson_slides").update(patch).eq("id", slide_id).execute()
    row = (updated.data or [None])[0]
    if not row:
        raise RuntimeError("Lesson slide not found.")
    return _to_item(row)


def delete_lesson_slide(client: Client, *, slide_id: str) -> None:
    client.table("lesson_slides").delete().eq("id", slide_id).execute()
