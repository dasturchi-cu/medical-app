from __future__ import annotations

from datetime import datetime
from typing import Any

from supabase import Client

from ..schemas.ranking import RankingItem

# Video va yakunlangan darslar uchun umumiy ball (test ballari — alohida `test_points`).
_WATCH_HOURS_WEIGHT = 10.0
_COMPLETED_LESSON_BONUS = 15.0


def compute_watch_score(*, total_watched_hours: float, completed_lessons: int) -> float:
    return round(total_watched_hours * _WATCH_HOURS_WEIGHT + completed_lessons * _COMPLETED_LESSON_BONUS, 2)


def ensure_user_rank_row(client: Client, *, user_id: str) -> dict[str, Any]:
    row_resp = client.table("user_ranks").select("*").eq("user_id", user_id).limit(1).execute()
    existing = (row_resp.data or [None])[0]
    if existing:
        return existing
    inserted = (
        client.table("user_ranks")
        .insert(
            {
                "user_id": user_id,
                "total_watched_hours": 0,
                "completed_lessons": 0,
                "total_score": 0,
                "quiz_minutes": 0,
                "test_points": 0,
            }
        )
        .execute()
    )
    return (inserted.data or [None])[0] or {}


def sync_user_rank_from_video_progress(client: Client, *, user_id: str) -> None:
    """video_progress dan soatlar/yakunlar yoziladi; total_score = test_points + video formula."""
    rows = (
        client.table("video_progress").select("watched_sec,completed").eq("user_id", user_id).execute()
    ).data or []
    total_sec = sum(int(r.get("watched_sec") or 0) for r in rows)
    completed_n = sum(1 for r in rows if r.get("completed"))
    hours = round(total_sec / 3600.0, 2)
    rank = ensure_user_rank_row(client, user_id=user_id)
    tp = float(rank.get("test_points") or 0)
    watch_score = compute_watch_score(total_watched_hours=hours, completed_lessons=completed_n)
    total = round(tp + watch_score, 2)
    client.table("user_ranks").update(
        {
            "total_watched_hours": hours,
            "completed_lessons": completed_n,
            "total_score": total,
            "updated_at": datetime.utcnow().isoformat(),
        }
    ).eq("user_id", user_id).execute()


def list_ranking(client: Client, *, limit: int = 50) -> list[RankingItem]:
    ranks_resp = (
        client.table("user_ranks")
        .select("user_id,total_score,total_watched_hours")
        .order("total_score", desc=True)
        .limit(limit)
        .execute()
    )
    ranks = ranks_resp.data or []
    if not ranks:
        return []
    user_ids = [row["user_id"] for row in ranks]
    users_resp = client.table("users").select("id,full_name").in_("id", user_ids).execute()
    names = {str(row.get("id")): str(row.get("full_name") or "Foydalanuvchi") for row in (users_resp.data or [])}
    items: list[RankingItem] = []
    for idx, row in enumerate(ranks, start=1):
        uid = str(row.get("user_id") or "")
        watch_hours = float(row.get("total_watched_hours") or 0)
        # Reyting sahifasida faqat video ko'rish vaqti ko'rsatiladi.
        study_minutes = round(watch_hours * 60.0)
        items.append(
            RankingItem(
                user_id=uid,
                full_name=names.get(uid, "Foydalanuvchi"),
                total_score=float(row.get("total_score") or 0),
                quiz_minutes=float(study_minutes),
                rank=idx,
            )
        )
    return items
