from pydantic import BaseModel, Field


class AdminUserItem(BaseModel):
    id: str
    name: str
    email: str
    registration_date: str
    login_count: int
    app_open_count: int
    is_blocked: bool


class AdminUsersResponse(BaseModel):
    items: list[AdminUserItem]


class GrantCourseRequest(BaseModel):
    course_id: str = Field(min_length=1)


class UserEntitlementItem(BaseModel):
    id: str
    course_id: str
    course_title: str
    purchased_at: str
    is_active: bool


class UserEntitlementsResponse(BaseModel):
    items: list[UserEntitlementItem]
