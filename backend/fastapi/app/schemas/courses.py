from datetime import datetime

from pydantic import BaseModel, Field


class CourseCreate(BaseModel):
    title_uz: str = Field(min_length=1, max_length=200)
    title_ru: str = ""
    title_en: str = ""
    price_uzs: float = Field(default=0, ge=0)
    admin_telegram: str = "Neuroscienceadmin"
    image_url: str = ""
    description_uz: str = ""


class CourseUpdate(BaseModel):
    title_uz: str | None = None
    title_ru: str | None = None
    title_en: str | None = None
    price_uzs: float | None = Field(default=None, ge=0)
    admin_telegram: str | None = None
    image_url: str | None = None
    description_uz: str | None = None
    is_active: bool | None = None


class CourseItem(BaseModel):
    id: str
    title_uz: str
    title_ru: str
    title_en: str
    price_uzs: float
    admin_telegram: str
    image_url: str
    description_uz: str = ""
    is_active: bool
    views: int = 0
    sales: int = 0
    created_at: datetime


class CourseListResponse(BaseModel):
    items: list[CourseItem]


class CourseStatsResponse(BaseModel):
    course_id: str
    enrolled_count: int
    comments_count: int = 0
    rating_avg: float = 0
    rating_count: int = 0
    my_rating: int | None = None


class CourseRateRequest(BaseModel):
    user_id: str = Field(min_length=1)
    stars: int = Field(ge=1, le=5)
