from functools import lru_cache

import httpx
from supabase import Client, create_client
from supabase.lib.client_options import SyncClientOptions

from .config import get_settings


@lru_cache(maxsize=1)
def get_supabase_client() -> Client:
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise RuntimeError("Supabase credentials are not configured.")
    # Force HTTP/1.1 for better stability on some Windows + network stacks.
    httpx_client = httpx.Client(http2=False, timeout=httpx.Timeout(20.0, connect=10.0))
    options = SyncClientOptions(httpx_client=httpx_client, postgrest_client_timeout=20)
    return create_client(settings.supabase_url, settings.supabase_service_role_key, options=options)
