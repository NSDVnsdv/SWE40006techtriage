# Below is the code to start from the official Python 3.12 image, in its small "slim" version.
FROM python:3.12-slim

# Below is the code to take the commit ID (SHA) from the pipeline and save it in the image as APP_VERSION,
# so /version can prove which build is running. It also makes Python print logs straight away.
ARG GIT_SHA=unknown
ENV APP_VERSION=${GIT_SHA} \
    APP_ENV=unknown \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Below is the code to work in the /app folder and install the Python packages before copying our code,
# so Docker can reuse this slow step from its cache when only our own code changes.
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Below is the code to copy in the app, the Gunicorn settings, the page templates and the troubleshooting rules.
COPY app.py rules.py gunicorn.conf.py ./
COPY templates/ templates/
COPY rules/ rules/

# Below is the code to create a normal user and run the app as that user instead of root, which is safer.
RUN useradd --create-home --uid 10001 app
USER app

# Below is the code to note that the app listens on port 8000 and to start it with Gunicorn,
# which reads its settings (port, 2 workers, JSON access log, table set-up) from gunicorn.conf.py.
EXPOSE 8000
CMD ["gunicorn", "app:app"]
