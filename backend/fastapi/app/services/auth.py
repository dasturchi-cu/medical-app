from __future__ import annotations

from datetime import datetime

from fastapi import HTTPException, status
from supabase import Client

from ..schemas.auth import AuthUserResponse, MobileLoginRequest, UserStatusResponse


def _normalize_phone(phone: str) -> str:
    return "".join(ch for ch in phone if ch.isdigit())


def mobile_login(client: Client, payload: MobileLoginRequest, *, admin_contact: str = "Neuroscienceadmin") -> AuthUserResponse:
    phone = _normalize_phone(payload.phone)
    if not phone:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Telefon raqam noto'g'ri.")

    user_resp = client.table("users").select("*").eq("phone", phone).limit(1).execute()
    user = (user_resp.data or [None])[0]
    if user is None:
        inserted = (
            client.table("users")
            .insert(
                {
                    "phone": phone,
                    "full_name": payload.display_name.strip() or f"User {phone[-4:]}",
                }
            )
            .execute()
        )
        user = (inserted.data or [None])[0]
        if user is None:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="User yaratilmadi.")

    if bool(user.get("is_blocked")):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Siz admin tomonidan bloklangansiz. Admin: @{admin_contact}",
        )

    # Device lock: one account => one primary device
    user_id = str(user["id"])
    device_resp = (
        client.table("user_devices")
        .select("*")
        .eq("user_id", user_id)
        .eq("is_primary", True)
        .limit(1)
        .execute()
    )
    primary = (device_resp.data or [None])[0]
    if primary is None:
        client.table("user_devices").insert(
            {
                "user_id": user_id,
                "device_id": payload.device_id,
                "platform": payload.platform,
                "is_primary": True,
            }
        ).execute()
    else:
        if str(primary.get("device_id") or "") != payload.device_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bu raqam boshqa qurilmaga ulangan.",
            )
        client.table("user_devices").update({"last_seen_at": datetime.utcnow().isoformat()}).eq("id", primary["id"]).execute()

    if payload.display_name.strip() and payload.display_name.strip() != str(user.get("full_name") or ""):
        updated = (
            client.table("users")
            .update({"full_name": payload.display_name.strip()})
            .eq("id", user_id)
            .execute()
        )
        updated_row = (updated.data or [None])[0]
        if updated_row:
            user = updated_row

    # Ensure user has delivery rows for existing notifications.
    notifications = client.table("notifications").select("id").execute().data or []
    if notifications:
        existing_deliveries = (
            client.table("notification_deliveries")
            .select("notification_id")
            .eq("user_id", user_id)
            .execute()
        ).data or []
        existing_ids = {str(row.get("notification_id")) for row in existing_deliveries}
        missing = [
            {"notification_id": row["id"], "user_id": user_id}
            for row in notifications
            if str(row.get("id")) not in existing_ids
        ]
        if missing:
            client.table("notification_deliveries").insert(missing).execute()

    return AuthUserResponse(
        user_id=user_id,
        phone=phone,
        full_name=str(user.get("full_name") or ""),
    )


def get_user_status(client: Client, *, user_id: str, admin_contact: str = "Neuroscienceadmin") -> UserStatusResponse:
    user_resp = client.table("users").select("id,is_blocked").eq("id", user_id).limit(1).execute()
    user = (user_resp.data or [None])[0]
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User topilmadi.")
    return UserStatusResponse(
        user_id=str(user.get("id") or user_id),
        is_blocked=bool(user.get("is_blocked")),
        admin_contact=admin_contact,
    )
