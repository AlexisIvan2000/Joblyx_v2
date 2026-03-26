FROM python:3.13-slim

WORKDIR /app

# Dépendances système pour asyncpg, argon2, spaCy
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Port dynamique Railway
EXPOSE ${PORT:-8000}

CMD uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}
