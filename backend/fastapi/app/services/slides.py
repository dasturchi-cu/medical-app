from __future__ import annotations

from datetime import datetime
from typing import Any

from supabase import Client

from ..schemas.slides import SlideCreate, SlideItem, SlideUpdate


def _to_item(row: dict[str, Any]) -> SlideItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return SlideItem(
        id=str(row.get("id") or ""),
        title=str(row.get("title") or ""),
        subtitle=str(row.get("subtitle") or ""),
        image_url=str(row.get("image_url") or ""),
        button_text=str(row.get("button_text") or "Boshlash"),
        course_id=row.get("course_id"),
        order_no=int(row.get("order_no") or 1),
        is_active=bool(row.get("is_active")),
        created_at=created,
    )


def list_slides(client: Client, *, active_only: bool = False) -> list[SlideItem]:
    query = client.table("home_slides").select("*").order("order_no", desc=False)
    if active_only:
        query = query.eq("is_active", True)
    response = query.execute()
    return [_to_item(row) for row in (response.data or [])]


def create_slide(client: Client, payload: SlideCreate) -> SlideItem:
    inserted = (
        client.table("home_slides")
        .insert(
            {
                "title": payload.title.strip(),
                "subtitle": payload.subtitle.strip(),
                "image_url": payload.image_url.strip(),
                "button_text": payload.button_text.strip() or "Boshlash",
                "course_id": payload.course_id,
                "order_no": payload.order_no,
            }
        )
        .execute()
    )
    item = (inserted.data or [None])[0]
    if not item:
        raise RuntimeError("Failed to create slide.")
    return _to_item(item)


def update_slide(client: Client, *, slide_id: str, payload: SlideUpdate) -> SlideItem:
    patch: dict[str, Any] = {}
    for key in ["title", "subtitle", "image_url", "button_text", "order_no", "is_active"]:
        value = getattr(payload, key)
        if value is not None:
            patch[key] = value.strip() if isinstance(value, str) else value
    if payload.course_id is not None:
        patch["course_id"] = payload.course_id

    updated = client.table("home_slides").update(patch).eq("id", slide_id).execute()
    item = (updated.data or [None])[0]
    if not item:
        raise RuntimeError("Slide not found.")
    return _to_item(item)


def delete_slide(client: Client, *, slide_id: str) -> None:
    client.table("home_slides").delete().eq("id", slide_id).execute()
