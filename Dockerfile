# Level 1 placeholder image. Level 3 replaces this with the Flask + Gunicorn app.
FROM python:3.12-slim

# Commit SHA passed in by GitHub Actions, baked into the image so every
# server can prove exactly which build it is running.
ARG GIT_SHA=unknown
ENV APP_VERSION=${GIT_SHA} \
    APP_ENV=unknown \
    PORT=8000 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY placeholder/server.py .

RUN useradd --create-home --uid 10001 app
USER app

EXPOSE 8000
CMD ["python", "server.py"]
