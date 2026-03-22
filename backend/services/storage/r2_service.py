import uuid
import asyncio
from functools import partial
import boto3
from core.config import R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT_URL, R2_BUCKET_NAME_RESUMES, R2_BUCKET_NAME_AVATARS

_s3 = boto3.client(
    "s3",
    endpoint_url=R2_ENDPOINT_URL,
    aws_access_key_id=R2_ACCESS_KEY_ID,
    aws_secret_access_key=R2_SECRET_ACCESS_KEY,
    region_name="auto",
)


class R2Service:
    # Client R2 Cloudflare (compatible S3) pour le stockage de CVs
    
    # Upload un CV et retourne le file_key
    async def upload_cv(self, user_id: str, file_bytes: bytes, filename: str) -> str:
        ext = filename.rsplit(".", 1)[-1] if "." in filename else "pdf"
        file_key = f"{user_id}/{uuid.uuid4()}.{ext}"

        await asyncio.get_event_loop().run_in_executor(
            None,
            partial(
                _s3.put_object,
                Bucket=R2_BUCKET_NAME_RESUMES,
                Key=file_key,
                Body=file_bytes,
                ContentType="application/pdf",
            ),
        )
        return file_key

    async def get_cv_url(self, file_key: str) -> str:
     # Génère une URL signée temporaire (1h) pour télécharger le CV.
        url = await asyncio.get_event_loop().run_in_executor(
            None,
            partial(
                _s3.generate_presigned_url,
                "get_object",
                Params={"Bucket": R2_BUCKET_NAME_RESUMES, "Key": file_key},
                ExpiresIn=3600,
            ),
        )
        return url

    async def delete_cv(self, file_key: str) -> None:
        # Supprime un CV du bucket.
        await asyncio.get_event_loop().run_in_executor(
            None,
            partial(
                _s3.delete_object,
                Bucket=R2_BUCKET_NAME_RESUMES,
                Key=file_key,
            ),
        )


    async def upload_avatar(self, user_id: str, file_bytes: bytes, content_type: str) -> str:
        # Upload un avatar et retourne le file_key. Écrase l'ancien si même user_id.
        ext = content_type.split("/")[-1] if "/" in content_type else "jpg"
        file_key = f"avatars/{user_id}.{ext}"

        await asyncio.get_event_loop().run_in_executor(
            None,
            partial(
                _s3.put_object,
                Bucket=R2_BUCKET_NAME_AVATARS,
                Key=file_key,
                Body=file_bytes,
                ContentType=content_type,
            ),
        )
        return file_key

    async def get_avatar_url(self, file_key: str) -> str:
        # URL signée temporaire (1h) pour l'avatar.
        url = await asyncio.get_event_loop().run_in_executor(
            None,
            partial(
                _s3.generate_presigned_url,
                "get_object",
                Params={"Bucket": R2_BUCKET_NAME_AVATARS, "Key": file_key},
                ExpiresIn=3600,
            ),
        )
        return url

    async def delete_avatar(self, file_key: str) -> None:
        # Supprime un avatar du bucket.
        await asyncio.get_event_loop().run_in_executor(
            None,
            partial(
                _s3.delete_object,
                Bucket=R2_BUCKET_NAME_AVATARS,
                Key=file_key,
            ),
        )
