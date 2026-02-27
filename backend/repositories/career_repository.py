from supabase import Client


class CareerRepository:
    def __init__(self, supabase_client: Client):
        self.supabase = supabase_client

    def get_career_profile_by_user_id(self, user_id: str) -> dict | None:
        result = self.supabase.table("career_profiles").select("*").eq("user_id", user_id).execute()
        return result.data[0] if result.data else None

    def create_career_profile(self, profile_data: dict) -> dict:
        result = self.supabase.table("career_profiles").insert(profile_data).execute()
        return result.data[0]

    def create_user_skills(self, skills_data: list[dict]) -> list[dict]:
        result = self.supabase.table("user_skills").insert(skills_data).execute()
        return result.data

    def create_roadmap(self, roadmap_data: dict) -> dict:
        result = self.supabase.table("roadmaps").insert(roadmap_data).execute()
        return result.data[0]

    def get_roadmap_by_user_id(self, user_id: str) -> dict | None:
        result = self.supabase.table("roadmaps").select("*").eq("user_id", user_id).execute()
        return result.data[0] if result.data else None

    def get_user_skills_by_user_id(self, user_id: str) -> list[dict]:
        result = self.supabase.table("user_skills").select("*").eq("user_id", user_id).execute()
        return result.data
