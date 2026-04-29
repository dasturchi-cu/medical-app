from fastapi import APIRouter, Query, status

from ..db import get_supabase_client
from ..schemas.comments import AddCommentRequest, AppCommentItem, AppCommentsResponse, ToggleLikeRequest
from ..services.comments import add_comment, list_comments, toggle_like

router = APIRouter(prefix="/comments", tags=["comments"])


@router.get("", response_model=AppCommentsResponse)
def get_comments(
    course_key: str = Query(min_length=1),
    user_id: str | None = Query(default=None),
):
    items = list_comments(get_supabase_client(), course_key=course_key, user_id=user_id)
    return AppCommentsResponse(items=items)


@router.post("", response_model=AppCommentItem, status_code=status.HTTP_201_CREATED)
def post_comment(payload: AddCommentRequest):
    return add_comment(get_supabase_client(), payload)


@router.post("/{comment_id}/like", response_model=AppCommentItem)
def post_toggle_like(comment_id: str, payload: ToggleLikeRequest):
    return toggle_like(get_supabase_client(), comment_id=comment_id, user_id=payload.user_id)
