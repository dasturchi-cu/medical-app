from __future__ import annotations

from datetime import datetime
from typing import Any

from supabase import Client

from ..schemas.admin_ads import AdminAdCreate, AdminAdItem, AdminAdUpdate


def _to_item(row: dict[str, Any]) -> AdminAdItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return AdminAdItem(
        id=str(row.get("id") or ""),
        title=str(row.get("title") or ""),
        message=str(row.get("message") or ""),
        image_url=str(row.get("image_url") or ""),
        price_label=str(row.get("price_label") or ""),
        course_id=str(row.get("course_id") or ""),
        telegram=str(row.get("telegram") or "Neuroscienceadmin"),
        is_active=bool(row.get("is_active")),
        created_at=created,
    )


def list_ads(client: Client) -> list[AdminAdItem]:
    rows = (
        client.table("course_banners")
        .select("*")
        .not_.is_("course_id", "null")
        .order("created_at", desc=True)
        .execute()
    ).data or []
    return [_to_item(row) for row in rows]


def create_ad(client: Client, payload: AdminAdCreate) -> AdminAdItem:
    inserted = (
        client.table("course_banners")
        .insert(
            {
                "title": payload.title.strip(),
                "message": payload.message.strip(),
                "image_url": payload.image_url.strip(),
                "price_label": payload.price_label.strip(),
                "course_id": payload.course_id,
                "telegram": payload.telegram.replace("@", "").strip() or "Neuroscienceadmin",
            }
        )
        .execute()
    )
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Failed to create ad.")
    return _to_item(row)


def update_ad(client: Client, *, ad_id: str, payload: AdminAdUpdate) -> AdminAdItem:
    patch: dict[str, Any] = {}
    for key in ["title", "message", "image_url", "price_label", "is_active"]:
        value = getattr(payload, key)
        if value is not None:
            patch[key] = value.strip() if isinstance(value, str) else value
    if payload.course_id is not None:
        patch["course_id"] = payload.course_id
    if payload.telegram is not None:
        patch["telegram"] = payload.telegram.replace("@", "").strip() or "Neuroscienceadmin"

    updated = client.table("course_banners").update(patch).eq("id", ad_id).execute()
    row = (updated.data or [None])[0]
    if not row:
        raise RuntimeError("Ad not found.")
    return _to_item(row)


def delete_ad(client: Client, *, ad_id: str) -> None:
    client.table("course_banners").delete().eq("id", ad_id).execute()
