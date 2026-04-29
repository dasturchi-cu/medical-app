from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.admin_comments import AdminCommentItem, AdminCommentReplyRequest, AdminCommentsResponse
from ..schemas.comments import AddCommentRequest, AppCommentItem, AppCommentsResponse, ToggleLikeRequest
from ..services.admin_comments import add_admin_reply, delete_admin_comment, list_admin_comments, toggle_admin_heart
from ..services.comments import add_comment, list_comments, toggle_like

router = APIRouter(prefix="/comments", tags=["comments"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> Settings:
    if settings.admin_api_key and x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")
    return settings


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


# Backward-compatible admin aliases to avoid Not Found during migrations.
@router.get("/admin", response_model=AdminCommentsResponse)
def get_admin_comments_alias(settings: Settings = Depends(_require_admin_key)):
    try:
        items = list_admin_comments(get_supabase_client(), configured_admin_user_id=settings.admin_user_id)
    except Exception:
        items = []
    return AdminCommentsResponse(items=items)


@router.post("/admin/{comment_id}/reply", response_model=AdminCommentItem, status_code=status.HTTP_201_CREATED)
def post_admin_reply_alias(comment_id: str, payload: AdminCommentReplyRequest, settings: Settings = Depends(_require_admin_key)):
    return add_admin_reply(
        get_supabase_client(),
        comment_id=comment_id,
        text=payload.text,
        configured_admin_user_id=settings.admin_user_id,
    )


@router.post("/admin/{comment_id}/toggle-heart", response_model=AdminCommentItem)
def post_admin_toggle_heart_alias(comment_id: str, settings: Settings = Depends(_require_admin_key)):
    return toggle_admin_heart(get_supabase_client(), comment_id=comment_id, configured_admin_user_id=settings.admin_user_id)


@router.delete("/admin/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_admin_comment_alias(comment_id: str, _: Settings = Depends(_require_admin_key)):
    delete_admin_comment(get_supabase_client(), comment_id=comment_id)
