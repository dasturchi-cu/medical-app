from fastapi import APIRouter, Depends, Header, HTTPException, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.admin_users import AdminUsersResponse, GrantCourseRequest, UserEntitlementsResponse
from ..services.admin_users import grant_user_course, list_admin_users, list_user_entitlements, revoke_user_course, set_user_blocked

router = APIRouter(prefix="/admin/users", tags=["admin-users"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("", response_model=AdminUsersResponse)
def get_users(_: None = Depends(_require_admin_key)):
    return AdminUsersResponse(items=list_admin_users(get_supabase_client()))


@router.post("/{user_id}/block", status_code=status.HTTP_204_NO_CONTENT)
def block_user(user_id: str, _: None = Depends(_require_admin_key)):
    set_user_blocked(get_supabase_client(), user_id=user_id, blocked=True)


@router.post("/{user_id}/unblock", status_code=status.HTTP_204_NO_CONTENT)
def unblock_user(user_id: str, _: None = Depends(_require_admin_key)):
    set_user_blocked(get_supabase_client(), user_id=user_id, blocked=False)


@router.post("/{user_id}/grant-course", status_code=status.HTTP_204_NO_CONTENT)
def grant_course(user_id: str, payload: GrantCourseRequest, _: None = Depends(_require_admin_key)):
    grant_user_course(get_supabase_client(), user_id=user_id, course_id=payload.course_id)


@router.get("/{user_id}/entitlements", response_model=UserEntitlementsResponse)
def get_user_entitlements(user_id: str, _: None = Depends(_require_admin_key)):
    return UserEntitlementsResponse(items=list_user_entitlements(get_supabase_client(), user_id=user_id))


@router.post("/{user_id}/revoke-course", status_code=status.HTTP_204_NO_CONTENT)
def revoke_course(user_id: str, payload: GrantCourseRequest, _: None = Depends(_require_admin_key)):
    revoke_user_course(get_supabase_client(), user_id=user_id, course_id=payload.course_id)
