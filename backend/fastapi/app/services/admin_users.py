from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from supabase import Client

from ..schemas.admin_users import AdminUserItem, UserEntitlementItem

logger = logging.getLogger(__name__)


def list_admin_users(client: Client) -> list[AdminUserItem]:
    try:
        rows = client.table("users").select("*").order("created_at", desc=False).execute().data or []
        items: list[AdminUserItem] = []
        for row in rows:
            created = str(row.get("created_at") or "")
            items.append(
                AdminUserItem(
                    id=str(row.get("id") or ""),
                    name=str(row.get("full_name") or "Foydalanuvchi"),
                    email=str(row.get("phone") or ""),
                    registration_date=created[:10] if created else "",
                    login_count=0,
                    app_open_count=0,
                    is_blocked=bool(row.get("is_blocked")),
                )
            )
        return items
    except Exception as error:
        logger.warning("Failed to list admin users from Supabase: %s", error)
        return []


def set_user_blocked(client: Client, *, user_id: str, blocked: bool) -> None:
    client.table("users").update({"is_blocked": blocked, "updated_at": datetime.utcnow().isoformat()}).eq("id", user_id).execute()


def grant_user_course(client: Client, *, user_id: str, course_id: str) -> None:
    existing = (
        client.table("user_entitlements")
        .select("id")
        .eq("user_id", user_id)
        .eq("course_id", course_id)
        .is_("section_id", None)
        .eq("is_active", True)
        .limit(1)
        .execute()
    ).data or []
    if existing:
        return
    client.table("user_entitlements").insert(
        {
            "user_id": user_id,
            "course_id": course_id,
            "section_id": None,
            "source": "admin_grant",
            "granted_by": "admin_panel",
            "is_active": True,
        }
    ).execute()


def list_user_entitlements(client: Client, *, user_id: str) -> list[UserEntitlementItem]:
    rows = (
        client.table("user_entitlements")
        .select("id,course_id,starts_at,created_at,is_active")
        .eq("user_id", user_id)
        .is_("section_id", None)
        .order("created_at", desc=True)
        .execute()
    ).data or []
    course_ids = [str(row.get("course_id")) for row in rows if row.get("course_id")]
    courses = (
        client.table("courses")
        .select("id,title_uz")
        .in_("id", course_ids)
        .execute()
    ).data if course_ids else []
    course_map = {str(row.get("id")): str(row.get("title_uz") or row.get("id") or "") for row in (courses or [])}
    items: list[UserEntitlementItem] = []
    for row in rows:
        course_id = str(row.get("course_id") or "")
        items.append(
            UserEntitlementItem(
                id=str(row.get("id") or ""),
                course_id=course_id,
                course_title=course_map.get(course_id, course_id),
                purchased_at=str(row.get("starts_at") or row.get("created_at") or ""),
                is_active=bool(row.get("is_active")),
            )
        )
    return items


def revoke_user_course(client: Client, *, user_id: str, course_id: str) -> None:
    client.table("user_entitlements").update({"is_active": False}).eq("user_id", user_id).eq("course_id", course_id).is_(
        "section_id", None
    ).execute()
