FROM python:3.11-slim AS builder

WORKDIR /src
COPY requirements.txt .

RUN python -m venv /venv && \
    /venv/bin/pip install --no-cache-dir --upgrade pip && \
    /venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim

# Aplica os patches de seguranca do SO na imagem final. O scan de container
# do pipeline pegou 3 CVEs CRITICAL em perl-base vindas da imagem base do
# Debian (CVE-2026-8376, CVE-2026-13221, CVE-2026-42496) — todas com correcao
# publicada. Sem este upgrade, a regra de bloqueio impede a publicacao.
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -u 1000 -m appuser
WORKDIR /app

COPY --from=builder /venv /venv
COPY . .

ENV PATH="/venv/bin:$PATH"

USER appuser
EXPOSE 8005

CMD ["gunicorn", "--bind", "0.0.0.0:8005", "--workers", "1", "app:app"]
