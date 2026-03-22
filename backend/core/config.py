from dotenv import load_dotenv
import os

load_dotenv()

JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "30"))

DATABASE_URL = os.getenv("DB_URL")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL_PRIMARY = "gpt-4o"        # Roadmap génération uniquement
OPENAI_MODEL_FAST = "gpt-4o-mini"      # Coach, simulateur, extraction skills

RESEND_API_KEY = os.getenv("RESEND_API_KEY")
RESEND_FROM_EMAIL = os.getenv("RESEND_FROM_EMAIL", "support@joblyx.com")
RESEND_FROM_NAME  = os.getenv("RESEND_FROM_NAME", "Joblyx")

FRONTEND_URL = os.getenv("FRONTEND_URL")

RAPIDAPI_KEY = os.getenv("RAPIDAPI_KEY")

R2_ACCESS_KEY_ID = os.getenv("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = os.getenv("R2_SECRET_ACCESS_KEY")
R2_ENDPOINT_URL = os.getenv("R2_ENDPOINT_URL")
R2_BUCKET_NAME_RESUMES = os.getenv("R2_BUCKET_NAME_RESUMES", "cvs")
R2_BUCKET_NAME_IMAGES = os.getenv("R2_BUCKET_NAME_IMAGES", "avatar")