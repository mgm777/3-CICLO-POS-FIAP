FROM python:3.11-slim AS builder

WORKDIR /src
COPY requirements.txt .

RUN python -m venv /venv && \
    /venv/bin/pip install --no-cache-dir --upgrade pip && \
    /venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim

RUN useradd -u 1000 -m appuser
WORKDIR /app

COPY --from=builder /venv /venv
COPY . .

ENV PATH="/venv/bin:$PATH"

USER appuser
EXPOSE 8005

CMD ["gunicorn", "--bind", "0.0.0.0:8005", "--workers", "1", "app:app"]
