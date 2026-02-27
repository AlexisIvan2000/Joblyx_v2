from supabase import Client

TABLE = "profiles_v2"

class AuthRepository:
    def __init__(self, supabase_client: Client):
        self.supabase = supabase_client

    def get_user_by_email(self, email: str) -> dict | None:
        result = self.supabase.table(TABLE).select("*").eq("email", email).execute()
        return result.data[0] if result.data else None

    def create_user(self, user_data: dict) -> dict:
        result = self.supabase.table(TABLE).insert(user_data).execute()
        return result.data[0]
    
    def get_user_by_id(self, user_id: str) -> dict | None:
        result = self.supabase.table(TABLE).select("*").eq("id", user_id).execute()
        return result.data[0] if result.data else None

    def update_user(self, user_id: str, data: dict) -> dict:
        result = self.supabase.table(TABLE).update(data).eq("id", user_id).execute()
        return result.data[0]

    def get_user_by_verification_token(self, token: str) -> dict | None:
        result = self.supabase.table(TABLE).select("*").eq("verification_token", token).execute()
        return result.data[0] if result.data else None

    def update_verification_status(self, user_id: str) -> dict:
        return self.update_user(user_id, {"is_verified": True, "verification_token": None, "verification_token_expires_at": None})

    def save_reset_token(self, email: str, token: str, expires_at: str) -> dict:
        result = self.supabase.table(TABLE).update({
            "reset_token": token,
            "reset_token_expires_at": expires_at
        }).eq("email", email).execute()
        return result.data[0]

    def update_password(self, user_id: str, new_password_hash: str) -> dict:
        return self.update_user(user_id, {"password_hash": new_password_hash, "reset_token": None, "reset_token_expires_at": None})
