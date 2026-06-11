import logging

from fastapi import FastAPI, Request

logger = logging.getLogger(__name__)

# Prefixes considérés comme versionnés ou techniques, non loggés
_KNOWN_PREFIXES = ("/v1/", "/health", "/docs", "/openapi", "/redoc")

 # Logue les appels aux routes non versionnées pour suivre la migration mobile
def register_legacy_route_logger(app: FastAPI) -> None:
    @app.middleware("http")
    async def log_legacy_routes(request: Request, call_next):
        path = request.url.path
        if not path.startswith(_KNOWN_PREFIXES):
            logger.warning("LEGACY ROUTE: %s %s", request.method, path)
        return await call_next(request)
