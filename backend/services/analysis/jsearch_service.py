import logging
import os
import httpx

logger = logging.getLogger(__name__)


class JSearchService:
    BASE_URL = "https://jsearch.p.rapidapi.com/search"

    def __init__(self):
        # Lecture directe depuis os.environ pour toujours avoir la clé à jour
        self.api_key = os.getenv("RAPIDAPI_KEY")

    @property
    def headers(self):
        return {
            "X-RapidAPI-Key": self.api_key or os.getenv("RAPIDAPI_KEY", ""),
            "X-RapidAPI-Host": "jsearch.p.rapidapi.com",
        }

    async def search_jobs(self, query: str, location: str = "", num_pages: int = 3) -> list[dict]:
        all_jobs = []

        async with httpx.AsyncClient(timeout=30) as client:
            params = {
                "query": f"{query} in {location}" if location else query,
                "page": 1,
                "num_pages": str(num_pages),
                "country": "ca",
                "date_posted": "month"
            }

            try:
                response = await client.get(
                    self.BASE_URL,
                    headers=self.headers,
                    params=params
                )
                response.raise_for_status()
                data = response.json()
                jobs = data.get("data", [])
                logger.info("Fetched %d jobs for query=%s location=%s", len(jobs), query, location)
                return jobs
            except httpx.HTTPStatusError as e:
                logger.warning("JSearch HTTP error: status=%s", e.response.status_code)
                return []
            except httpx.RequestError as e:
                logger.warning("JSearch request failed: %s", e)
                return []
            
    async def get_job_descriptions(self, query: str, location: str = "", num_pages: int = 3) -> list[str]:
        jobs = await self.search_jobs(query, location, num_pages)
        descriptions = []

        for job in jobs:
            description = job.get("job_description", "")
            if description:
                descriptions.append(description)

        return descriptions
    

jsearch_service = JSearchService()