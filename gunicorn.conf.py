# Below is the code to make Gunicorn (the program that runs the app on the servers) listen on port 8000
# with 2 worker processes. Two is plenty for our traffic and keeps memory low on the small t3.micro servers.
bind = "0.0.0.0:8001git add gunicorn.conf.py"
workers = 2

# Below is the code to print one JSON line per request to the screen, including the response time in milliseconds.
# Level 2 sends these lines to CloudWatch, which turns them into the request, latency and 5xx error graphs.
accesslog = "-"
access_log_format = '{"type": "access", "method": "%(m)s", "path": "%(U)s", "status": %(s)s, "duration_ms": %(M)s}'


# Below is the code to run one job when Gunicorn starts, before any page is served.
# It creates the database tables if they are missing, so a brand-new server sets itself up.
def on_starting(server):
    from app import init_db

    init_db()
