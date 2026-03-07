import os
import httpx

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
                print(f"Fetched {len(jobs)} jobs for query '{query}' in location '{location}'")
                return jobs
            except httpx.HTTPStatusError as e:
                print(f"HTTP error occurred: {e.response.status_code} - {e.response.text}")
                return []
            except httpx.RequestError as e:
                print(f"An error occurred while requesting: {e}")
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