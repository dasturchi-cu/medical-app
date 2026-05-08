import logging
import time

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from .api.auth import router as auth_router
from .api.admin_ads import router as admin_ads_router
from .api.admin_ratings import router as admin_ratings_router
from .api.admin_users import router as admin_users_router
from .api.admin_comments import router as admin_comments_router
from .api.banners import router as banners_router
from .api.courses import router as courses_router
from .api.mobile import router as mobile_router
from .api.purchases import router as purchases_router
from .api.ranking import router as ranking_router
from .api.notifications import router as notifications_router
from .api.comments import router as comments_router
from .api.feedback import router as feedback_router
from .api.lesson_slides import router as lesson_slides_router
from .api.lessons import router as lessons_router
from .api.slides import router as slides_router
from .api.subscriptions_admin import router as subscriptions_router
from .api.tests import router as tests_router
from .config import get_settings

settings = get_settings()
app = FastAPI(title=settings.app_name)
logger = logging.getLogger(__name__)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.frontend_origin, "*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(notifications_router, prefix=settings.api_prefix)
app.include_router(auth_router, prefix=settings.api_prefix)
app.include_router(admin_ads_router, prefix=settings.api_prefix)
app.include_router(admin_ratings_router, prefix=settings.api_prefix)
app.include_router(admin_users_router, prefix=settings.api_prefix)
app.include_router(admin_comments_router, prefix=settings.api_prefix)
app.include_router(comments_router, prefix=settings.api_prefix)
app.include_router(feedback_router, prefix=settings.api_prefix)
app.include_router(lesson_slides_router, prefix=settings.api_prefix)
app.include_router(lessons_router, prefix=settings.api_prefix)
app.include_router(slides_router, prefix=settings.api_prefix)
app.include_router(subscriptions_router, prefix=settings.api_prefix)
app.include_router(tests_router, prefix=settings.api_prefix)
app.include_router(purchases_router, prefix=settings.api_prefix)
app.include_router(ranking_router, prefix=settings.api_prefix)
app.include_router(mobile_router, prefix=settings.api_prefix)
app.include_router(courses_router, prefix=settings.api_prefix)
app.include_router(banners_router, prefix=settings.api_prefix)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    started = time.perf_counter()
    logger.info(
        "api.request method=%s path=%s query=%s",
        request.method,
        request.url.path,
        request.url.query,
    )
    response = await call_next(request)
    elapsed_ms = int((time.perf_counter() - started) * 1000)
    logger.info(
        "api.response method=%s path=%s status=%s elapsed_ms=%s",
        request.method,
        request.url.path,
        response.status_code,
        elapsed_ms,
    )
    return response


@app.get("/health")
def healthcheck():
    return {"ok": True, "service": settings.app_name, "environment": settings.environment}
