from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from supabase import Client

from ..schemas.admin_users import (
    AdminUserItem,
    AdminUserUpdateRequest,
    UserEntitlementItem,
    UserOverviewMetrics,
    UserOverviewResponse,
    UserProgressItem,
    UserRecentCommentItem,
    UserRecentRatingItem,
)

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


def update_admin_user(client: Client, *, user_id: str, payload: AdminUserUpdateRequest) -> AdminUserItem:
    patch: dict[str, Any] = {"updated_at": datetime.utcnow().isoformat()}
    if payload.name is not None:
        patch["full_name"] = payload.name.strip()
    if payload.email is not None:
        patch["phone"] = payload.email.strip()
    if payload.is_blocked is not None:
        patch["is_blocked"] = payload.is_blocked
    if len(patch) == 1:
        raise RuntimeError("No fields to update.")

    result = client.table("users").update(patch).eq("id", user_id).execute()
    row = (result.data or [None])[0]
    if not row:
        raise RuntimeError("User not found.")
    created = str(row.get("created_at") or "")
    return AdminUserItem(
        id=str(row.get("id") or ""),
        name=str(row.get("full_name") or "Foydalanuvchi"),
        email=str(row.get("phone") or ""),
        registration_date=created[:10] if created else "",
        login_count=0,
        app_open_count=0,
        is_blocked=bool(row.get("is_blocked")),
    )


def delete_admin_user(client: Client, *, user_id: str) -> None:
    client.table("users").delete().eq("id", user_id).execute()


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


def get_user_overview(client: Client, *, user_id: str) -> UserOverviewResponse:
    entitlements = (
        client.table("user_entitlements")
        .select("id,course_id,is_active")
        .eq("user_id", user_id)
        .execute()
    ).data or []
    active_courses = {str(row.get("course_id") or "") for row in entitlements if row.get("is_active") and row.get("course_id")}
    total_entitlements = len([row for row in entitlements if row.get("course_id")])

    ratings_total = client.table("ratings").select("id", count="exact").eq("user_id", user_id).execute()
    ratings = (
        client.table("ratings")
        .select("course_id,stars,created_at")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(20)
        .execute()
    ).data or []
    comments_total = client.table("app_comments").select("id", count="exact").eq("user_id", user_id).execute()
    replies_total = (
        client.table("app_comments")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .not_.is_("parent_id", "null")
        .execute()
    )
    comments = (
        client.table("app_comments")
        .select("id,course_key,text,likes_count,replies_count,created_at,user_id")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(20)
        .execute()
    ).data or []
    likes = client.table("app_comment_likes").select("id", count="exact").eq("user_id", user_id).execute()

    progress_rows = (
        client.table("video_progress")
        .select("lesson_id,watched_sec,completed,updated_at,lessons!inner(course_id)")
        .eq("user_id", user_id)
        .order("updated_at", desc=True)
        .limit(50)
        .execute()
    ).data or []
    watched_lessons_count = len(progress_rows)
    completed_lessons_count = len([row for row in progress_rows if row.get("completed")])
    watched_seconds_total = sum(int(row.get("watched_sec") or 0) for row in progress_rows)

    payments = (
        client.table("payments")
        .select("id,amount_uzs,status,user_id")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(200)
        .execute()
    ).data or []
    paid_payments = [row for row in payments if str(row.get("status") or "").lower() in {"paid", "success"}]
    purchases_count = len(paid_payments)
    paid_total_uzs = float(sum(float(row.get("amount_uzs") or 0) for row in paid_payments))

    course_ids_from_ratings = [str(row.get("course_id")) for row in ratings if row.get("course_id")]
    course_ids_from_progress = [str((row.get("lessons") or {}).get("course_id")) for row in progress_rows if (row.get("lessons") or {}).get("course_id")]
    course_ids = list({*course_ids_from_ratings, *course_ids_from_progress, *list(active_courses)})
    courses_map: dict[str, str] = {}
    if course_ids:
        courses_rows = client.table("courses").select("id,title_uz").in_("id", course_ids).execute().data or []
        courses_map = {str(row.get("id")): str(row.get("title_uz") or row.get("id") or "") for row in courses_rows}

    recent_ratings = [
        UserRecentRatingItem(
            course_id=str(row.get("course_id") or ""),
            course_title=courses_map.get(str(row.get("course_id") or ""), str(row.get("course_id") or "")),
            stars=int(row.get("stars") or 0),
            created_at=str(row.get("created_at") or ""),
        )
        for row in ratings
    ]
    recent_comments = [
        UserRecentCommentItem(
            id=str(row.get("id") or ""),
            course_key=str(row.get("course_key") or ""),
            text=str(row.get("text") or ""),
            likes_count=int(row.get("likes_count") or 0),
            replies_count=int(row.get("replies_count") or 0),
            created_at=str(row.get("created_at") or ""),
        )
        for row in comments
    ]
    progress_items = [
        UserProgressItem(
            lesson_id=str(row.get("lesson_id") or ""),
            course_id=str((row.get("lessons") or {}).get("course_id") or ""),
            course_title=courses_map.get(str((row.get("lessons") or {}).get("course_id") or ""), str((row.get("lessons") or {}).get("course_id") or "")),
            watched_sec=int(row.get("watched_sec") or 0),
            completed=bool(row.get("completed")),
            updated_at=str(row.get("updated_at") or ""),
        )
        for row in progress_rows
    ]

    return UserOverviewResponse(
        user_id=user_id,
        metrics=UserOverviewMetrics(
            active_courses=len(active_courses),
            total_entitlements=total_entitlements,
            ratings_count=int(ratings_total.count or 0),
            comments_count=int(comments_total.count or 0),
            likes_given_count=int(likes.count or 0),
            replies_count=int(replies_total.count or 0),
            watched_lessons_count=watched_lessons_count,
            completed_lessons_count=completed_lessons_count,
            watched_seconds_total=watched_seconds_total,
            purchases_count=purchases_count,
            paid_total_uzs=paid_total_uzs,
        ),
        recent_ratings=recent_ratings,
        recent_comments=recent_comments,
        progress_items=progress_items,
    )
