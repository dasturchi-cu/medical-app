from __future__ import annotations

import logging
from supabase import Client

from ..schemas.mobile_catalog import MobileCatalogResponse, MobileCourse, MobileLesson, MobileSection

logger = logging.getLogger(__name__)


def get_mobile_catalog(client: Client) -> MobileCatalogResponse:
    try:
        courses_rows = (
            client.table("courses")
            .select("id,title_uz,title_ru,title_en,admin_telegram,price_uzs,image_url")
            .eq("is_active", True)
            .order("created_at", desc=False)
            .execute()
        ).data or []

        sections_rows = (
            client.table("course_sections")
            .select("id,course_id,title,order_no")
            .eq("is_active", True)
            .order("order_no", desc=False)
            .execute()
        ).data or []

        lessons_rows = (
            client.table("lessons")
            .select("id,course_id,section_id,title,video_url,duration_sec,order_no,is_free")
            .order("order_no", desc=False)
            .execute()
        ).data or []

        lessons_by_section: dict[str, list[MobileLesson]] = {}
        root_lessons_by_course: dict[str, list[MobileLesson]] = {}
        for row in lessons_rows:
            lesson = MobileLesson(
                id=str(row.get("id") or ""),
                title=str(row.get("title") or ""),
                video_url=str(row.get("video_url") or ""),
                duration_sec=int(row.get("duration_sec") or 0),
                order_no=int(row.get("order_no") or 1),
                is_free=bool(row.get("is_free")),
            )
            section_id = str(row.get("section_id") or "")
            course_id = str(row.get("course_id") or "")
            if section_id:
                lessons_by_section.setdefault(section_id, []).append(lesson)
            elif course_id:
                root_lessons_by_course.setdefault(course_id, []).append(lesson)

        sections_by_course: dict[str, list[MobileSection]] = {}
        for row in sections_rows:
            course_id = str(row.get("course_id") or "")
            if not course_id:
                continue
            section_id = str(row.get("id") or "")
            sections_by_course.setdefault(course_id, []).append(
                MobileSection(
                    id=section_id,
                    title=str(row.get("title") or ""),
                    order_no=int(row.get("order_no") or 1),
                    lessons=lessons_by_section.get(section_id, []),
                )
            )

        items: list[MobileCourse] = []
        for row in courses_rows:
            course_id = str(row.get("id") or "")
            sections = list(sections_by_course.get(course_id, []))
            root_lessons = root_lessons_by_course.get(course_id, [])
            if root_lessons:
                sections.insert(
                    0,
                    MobileSection(
                        id=f"{course_id}_root",
                        title="Asosiy darslar",
                        order_no=0,
                        lessons=sorted(root_lessons, key=lambda item: item.order_no),
                    ),
                )
            items.append(
                MobileCourse(
                    id=course_id,
                    title_uz=str(row.get("title_uz") or ""),
                    title_ru=str(row.get("title_ru") or ""),
                    title_en=str(row.get("title_en") or ""),
                    admin_telegram=str(row.get("admin_telegram") or ""),
                    price_uzs=float(row.get("price_uzs") or 0),
                    image_url=str(row.get("image_url") or ""),
                    sections=sections,
                )
            )
        return MobileCatalogResponse(items=items)
    except Exception as error:
        logger.warning("Failed to load mobile catalog from Supabase: %s", error)
        return MobileCatalogResponse(items=[])
