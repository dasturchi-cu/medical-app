from __future__ import annotations

from supabase import Client

from ..schemas.ranking import RankingItem


def list_ranking(client: Client, *, limit: int = 50) -> list[RankingItem]:
    ranks_resp = (
        client.table("user_ranks")
        .select("user_id,total_score,quiz_minutes")
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
      items.append(
          RankingItem(
              user_id=uid,
              full_name=names.get(uid, "Foydalanuvchi"),
              total_score=float(row.get("total_score") or 0),
              quiz_minutes=float(row.get("quiz_minutes") or 0),
              rank=idx,
          )
      )
    return items
