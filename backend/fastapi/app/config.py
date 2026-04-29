from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "medical-backend"
    api_prefix: str = "/api/v1"
    environment: str = "development"
    frontend_origin: str = "http://localhost:3000"
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    admin_api_key: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
