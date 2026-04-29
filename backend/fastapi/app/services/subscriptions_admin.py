from __future__ import annotations

import logging
from supabase import Client

from ..schemas.subscriptions_admin import CourseBuyerItem, CourseSubscriptionItem, SubscriptionsOverviewResponse

logger = logging.getLogger(__name__)


def get_subscriptions_overview(client: Client) -> SubscriptionsOverviewResponse:
    try:
        entitlements = (
            client.table("user_entitlements")
            .select("user_id,course_id,created_at")
            .eq("is_active", True)
            .execute()
        ).data or []

        if not entitlements:
            return SubscriptionsOverviewResponse(total_course_sales=0, total_unique_buyers=0, items=[])

        course_ids = list({str(row.get("course_id") or "") for row in entitlements if row.get("course_id")})
        user_ids = list({str(row.get("user_id") or "") for row in entitlements if row.get("user_id")})

        courses_rows = client.table("courses").select("id,title_uz").in_("id", course_ids).execute().data or []
        users_rows = client.table("users").select("id,full_name,phone").in_("id", user_ids).execute().data or []

        course_titles = {str(row.get("id")): str(row.get("title_uz") or "") for row in courses_rows}
        users_map = {
            str(row.get("id")): {
                "name": str(row.get("full_name") or "Foydalanuvchi"),
                "email": str(row.get("phone") or ""),
            }
            for row in users_rows
        }

        grouped: dict[str, list[CourseBuyerItem]] = {}
        for row in entitlements:
            course_id = str(row.get("course_id") or "")
            user_id = str(row.get("user_id") or "")
            if not course_id or not user_id:
                continue
            user_info = users_map.get(user_id, {"name": "Foydalanuvchi", "email": ""})
            grouped.setdefault(course_id, []).append(
                CourseBuyerItem(
                    user_id=user_id,
                    user_name=str(user_info["name"]),
                    user_email=str(user_info["email"]),
                    purchased_at=str(row.get("created_at") or ""),
                )
            )

        items = [
            CourseSubscriptionItem(
                course_id=course_id,
                course_title=course_titles.get(course_id, course_id),
                buyers=buyers,
            )
            for course_id, buyers in grouped.items()
        ]
        items.sort(key=lambda item: len(item.buyers), reverse=True)

        return SubscriptionsOverviewResponse(
            total_course_sales=len(entitlements),
            total_unique_buyers=len({str(row.get("user_id") or "") for row in entitlements}),
            items=items,
        )
    except Exception as error:
        logger.warning("Failed to build subscriptions overview from Supabase: %s", error)
        return SubscriptionsOverviewResponse(total_course_sales=0, total_unique_buyers=0, items=[])
