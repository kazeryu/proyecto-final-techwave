FROM python:3.12-slim AS build

WORKDIR /src
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin appuser \
    && mkdir -p /srv /tmp \
    && chown appuser:appuser /srv /tmp

COPY --from=build /install /usr/local
WORKDIR /srv
COPY app/app.py /srv/app.py
RUN chmod 644 /srv/app.py && chown -R 10001:10001 /srv

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/tmp

USER 10001
EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')"]

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "app:app"]
