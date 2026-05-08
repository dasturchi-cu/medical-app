from datetime import datetime
from pydantic import BaseModel, Field


class AdminAdCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    message: str = ""
    image_url: str = ""
    price_label: str = ""
    course_id: str = Field(min_length=1)
    telegram: str = "Neuroscienceadmin"


class AdminAdUpdate(BaseModel):
    title: str | None = None
    message: str | None = None
    image_url: str | None = None
    price_label: str | None = None
    course_id: str | None = None
    telegram: str | None = None
    is_active: bool | None = None


class AdminAdItem(BaseModel):
    id: str
    title: str
    message: str
    image_url: str
    price_label: str
    course_id: str
    telegram: str
    is_active: bool
    created_at: datetime


class AdminAdListResponse(BaseModel):
    items: list[AdminAdItem]
