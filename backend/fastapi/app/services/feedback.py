from supabase import Client


def get_feedback_stats(client: Client, *, content_key: str, user_id: str | None = None):
    comments_count = int(
        (
            client.table("app_comments")
            .select("id", count="exact")
            .eq("course_key", content_key)
            .execute()
        ).count
        or 0
    )
    rows = (
        client.table("app_ratings")
        .select("stars,user_id")
        .eq("content_key", content_key)
        .execute()
    ).data or []
    if not rows:
        return comments_count, 0.0, 0, None
    stars = [int(row.get("stars") or 0) for row in rows]
    rating_count = len(stars)
    rating_avg = round(sum(stars) / rating_count, 2) if rating_count > 0 else 0.0
    my_rating = None
    uid = (user_id or "").strip()
    if uid:
        mine = (
            client.table("app_ratings")
            .select("stars")
            .eq("content_key", content_key)
            .eq("user_id", uid)
            .limit(1)
            .execute()
        ).data or []
        if mine:
            my_rating = int(mine[0].get("stars") or 0)
        else:
            for row in rows:
                if str(row.get("user_id") or "").strip() == uid:
                    my_rating = int(row.get("stars") or 0)
                    break
    return comments_count, rating_avg, rating_count, my_rating


def upsert_feedback_rating(client: Client, *, content_key: str, user_id: str, stars: int) -> None:
    client.table("app_ratings").upsert(
        {"content_key": content_key, "user_id": user_id, "stars": stars},
        on_conflict="content_key,user_id",
    ).execute()
