import pytest

from unittest.mock import AsyncMock, patch, MagicMock
from cron.refresh_market_cache import refresh_market_cache


class TestRefreshMarketCache:
    @pytest.mark.asyncio
    async def test_calls_refresh_cache(self):
        mock_svc = AsyncMock()
        mock_svc.refresh_cache.return_value = {"processed": 5, "skipped": 1, "total": 6}

        mock_session = AsyncMock()

        with patch("cron.refresh_market_cache.AsyncSessionLocal") as mock_session_factory, \
             patch("cron.refresh_market_cache.MarketCacheService", return_value=mock_svc):

            mock_session_factory.return_value.__aenter__ = AsyncMock(return_value=mock_session)
            mock_session_factory.return_value.__aexit__ = AsyncMock(return_value=False)

            await refresh_market_cache()

        mock_svc.refresh_cache.assert_called_once()

    @pytest.mark.asyncio
    async def test_rollback_on_error(self):
        mock_svc = AsyncMock()
        mock_svc.refresh_cache.side_effect = Exception("DB error")

        mock_session = AsyncMock()

        with patch("cron.refresh_market_cache.AsyncSessionLocal") as mock_session_factory, \
             patch("cron.refresh_market_cache.MarketCacheService", return_value=mock_svc):

            mock_session_factory.return_value.__aenter__ = AsyncMock(return_value=mock_session)
            mock_session_factory.return_value.__aexit__ = AsyncMock(return_value=False)

            await refresh_market_cache()

        mock_session.rollback.assert_called_once()
