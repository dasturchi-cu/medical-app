from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.courses import CourseCreate, CourseItem, CourseListResponse, CourseRateRequest, CourseStatsResponse, CourseUpdate
from ..services.courses import (
    create_course,
    delete_course,
    get_course_comments_count,
    get_course_enrolled_count,
    get_course_rating_summary,
    list_courses,
    update_course,
    upsert_course_rating,
)

router = APIRouter(prefix="/courses", tags=["courses"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("", response_model=CourseListResponse)
def get_courses(active_only: bool = Query(default=False)):
    return CourseListResponse(items=list_courses(get_supabase_client(), active_only=active_only))


@router.post("", response_model=CourseItem, status_code=status.HTTP_201_CREATED)
def post_course(payload: CourseCreate, _: None = Depends(_require_admin_key)):
    return create_course(get_supabase_client(), payload)


@router.patch("/{course_id}", response_model=CourseItem)
def patch_course(course_id: str, payload: CourseUpdate, _: None = Depends(_require_admin_key)):
    return update_course(get_supabase_client(), course_id=course_id, payload=payload)


@router.delete("/{course_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_course(course_id: str, _: None = Depends(_require_admin_key)):
    delete_course(get_supabase_client(), course_id=course_id)


@router.get("/{course_id}/stats", response_model=CourseStatsResponse)
def get_course_stats(course_id: str, user_id: str | None = Query(default=None)):
    try:
        enrolled_count = get_course_enrolled_count(get_supabase_client(), course_id=course_id)
    except Exception:
        enrolled_count = 0
    try:
        comments_count = get_course_comments_count(get_supabase_client(), course_id=course_id)
    except Exception:
        comments_count = 0
    try:
        rating_avg, rating_count, my_rating = get_course_rating_summary(get_supabase_client(), course_id=course_id, user_id=user_id)
    except Exception:
        rating_avg, rating_count, my_rating = 0.0, 0, None
    return CourseStatsResponse(
        course_id=course_id,
        enrolled_count=enrolled_count,
        comments_count=comments_count,
        rating_avg=rating_avg,
        rating_count=rating_count,
        my_rating=my_rating,
    )


@router.post("/{course_id}/rate", status_code=status.HTTP_204_NO_CONTENT)
def post_course_rating(course_id: str, payload: CourseRateRequest):
    upsert_course_rating(get_supabase_client(), course_id=course_id, user_id=payload.user_id, stars=payload.stars)
