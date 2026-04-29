from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api.notifications import router as notifications_router
from .api.comments import router as comments_router
from .api.lesson_slides import router as lesson_slides_router
from .api.slides import router as slides_router
from .api.tests import router as tests_router
from .config import get_settings

settings = get_settings()
app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.frontend_origin, "*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(notifications_router, prefix=settings.api_prefix)
app.include_router(comments_router, prefix=settings.api_prefix)
app.include_router(lesson_slides_router, prefix=settings.api_prefix)
app.include_router(slides_router, prefix=settings.api_prefix)
app.include_router(tests_router, prefix=settings.api_prefix)


@app.get("/health")
def healthcheck():
    return {"ok": True, "service": settings.app_name, "environment": settings.environment}
