from datetime import datetime, timezone
from sqlalchemy import select, delete, update, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from models.db_models import InterviewSession, InterviewMessage, User


class InterviewRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    #  Sessions 

    async def create_session(self, data: dict) -> InterviewSession:
        session = InterviewSession(**data)
        self.session.add(session)
        await self.session.flush()
        await self.session.refresh(session)
        return session

    async def get_session_by_id(self, session_id: str, user_id: str) -> InterviewSession | None:
        result = await self.session.execute(
            select(InterviewSession)
            .options(selectinload(InterviewSession.messages))
            .where(InterviewSession.id == session_id, InterviewSession.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def update_session(self, session_id: str, data: dict) -> None:
        await self.session.execute(
            update(InterviewSession)
            .where(InterviewSession.id == session_id)
            .values(**data)
        )
        await self.session.flush()

    async def get_sessions_by_user(self, user_id: str) -> list[InterviewSession]:
        result = await self.session.execute(
            select(InterviewSession)
            .options(selectinload(InterviewSession.messages))
            .where(InterviewSession.user_id == user_id)
            .order_by(InterviewSession.created_at.desc())
        )
        return list(result.scalars().all())

    async def delete_session(self, session_id: str, user_id: str) -> bool:
        session = await self.get_session_by_id(session_id, user_id)
        if not session:
            return False
        # Les messages sont supprimés en cascade
        await self.session.delete(session)
        await self.session.flush()
        return True

    async def delete_all_by_user(self, user_id: str) -> int:
        result = await self.session.execute(
            select(func.count()).select_from(InterviewSession).where(
                InterviewSession.user_id == user_id
            )
        )
        count = result.scalar() or 0
        if count > 0:
            await self.session.execute(
                delete(InterviewSession).where(InterviewSession.user_id == user_id)
            )
            await self.session.flush()
        return count

    #  Messages 

    async def create_message(self, data: dict) -> InterviewMessage:
        msg = InterviewMessage(**data)
        self.session.add(msg)
        await self.session.flush()
        return msg

    async def get_messages_by_session(self, session_id: str) -> list[InterviewMessage]:
        result = await self.session.execute(
            select(InterviewMessage)
            .where(InterviewMessage.session_id == session_id)
            .order_by(InterviewMessage.position)
        )
        return list(result.scalars().all())

    async def count_assistant_messages(self, session_id: str) -> int:
        result = await self.session.execute(
            select(func.count()).select_from(InterviewMessage).where(
                InterviewMessage.session_id == session_id,
                InterviewMessage.role == "assistant",
            )
        )
        return result.scalar() or 0

    #  Usage tracking 

    async def get_usage(self, user_id: str) -> dict:
        result = await self.session.execute(
            select(User.interview_usage_count, User.interview_usage_reset_at).where(
                User.id == user_id
            )
        )
        row = result.one_or_none()
        if not row:
            return {"interview_usage_count": 0, "interview_usage_reset_at": None}
        return {
            "interview_usage_count": row[0] or 0,
            "interview_usage_reset_at": row[1],
        }

    async def increment_usage(self, user_id: str) -> None:
        await self.session.execute(
            update(User)
            .where(User.id == user_id)
            .values(interview_usage_count=User.interview_usage_count + 1)
        )
        await self.session.flush()

    async def reset_usage(self, user_id: str, reset_at: datetime) -> None:
        await self.session.execute(
            update(User)
            .where(User.id == user_id)
            .values(interview_usage_count=0, interview_usage_reset_at=reset_at)
        )
        await self.session.flush()
