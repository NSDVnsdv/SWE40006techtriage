# Below is the code to bring in the tools the app needs: os reads settings, time is used by a test page,
# psycopg talks to the PostgreSQL database and Flask builds the web pages.
import os
import time

import psycopg
from flask import Flask, abort, redirect, render_template, request, url_for

from rules import categories, find_rule, load_rules, rules_in_category

# Below is the code to read the settings each server gives the app (from its .env file, through Docker).
# The default values are only used when running on a laptop.
APP_ENV = os.environ.get("APP_ENV", "development")
APP_VERSION = os.environ.get("APP_VERSION", "unknown")
DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://techtriage:techtriage@localhost:5432/techtriage")
FAULT_INJECTION = os.environ.get("FAULT_INJECTION", "0") == "1"

# Below is the code to create the Flask app, load all the troubleshooting rules once at start-up,
# and let every page show which environment and version is running.
app = Flask(__name__)
RULES = load_rules()
app.jinja_env.globals.update(app_env=APP_ENV, app_version=APP_VERSION)

# Below is the code to create the two database tables (written in SQL) if they do not exist yet.
# "IF NOT EXISTS" means running it again never deletes or changes data that is already saved.
SCHEMA = """
CREATE TABLE IF NOT EXISTS triage_sessions (
    id SERIAL PRIMARY KEY,
    category TEXT NOT NULL,
    symptom TEXT NOT NULL,
    rule_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS feedback (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL UNIQUE REFERENCES triage_sessions (id),
    fixed BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
"""


# Below is the code to open a connection to the database. It gives up after 3 seconds,
# so a page or the health check never hangs when the database is down.
def connect():
    return psycopg.connect(DATABASE_URL, connect_timeout=3)


# Below is the code to create the database tables. Gunicorn runs it once when the app starts.
def init_db():
    with connect() as conn:
        conn.execute(SCHEMA)


# Below is the code to do the maths for the stats page: total sessions, most common category and fix rate.
# If two categories tie, the one first in the alphabet wins; with no Yes/No answers yet the fix rate is 0.
def build_stats(category_counts, fixed_count, answered_count):
    total = sum(category_counts.values())
    top_category = max(sorted(category_counts), key=category_counts.get) if category_counts else None
    fix_rate = round(100 * fixed_count / answered_count, 1) if answered_count else 0.0
    return {
        "total": total,
        "top_category": top_category,
        "fix_rate": fix_rate,
        "answered": answered_count,
        "by_category": category_counts,
    }


# Below is the code to show the home page. With no category chosen it lists the categories;
# after one is clicked (for example /?category=Docker) it also lists that category's symptoms.
@app.get("/")
def home():
    chosen = request.args.get("category")
    if chosen is not None and chosen not in categories(RULES):
        abort(404)
    category_list = [(name, len(rules_in_category(RULES, name))) for name in categories(RULES)]
    symptoms = rules_in_category(RULES, chosen) if chosen else []
    return render_template("index.html", categories=category_list, chosen=chosen, symptoms=symptoms)


# Below is the code to handle a picked symptom. An unknown symptom is rejected (error 400);
# a real one is saved as a new triage session and the user is sent to its results page.
@app.post("/triage")
def triage():
    rule = find_rule(RULES, request.form.get("rule_id", ""))
    if rule is None:
        abort(400, description="Unknown symptom. Please pick one from the list.")
    with connect() as conn:
        session_id = conn.execute(
            "INSERT INTO triage_sessions (category, symptom, rule_id) VALUES (%s, %s, %s) RETURNING id",
            (rule["category"], rule["symptom"], rule["id"]),
        ).fetchone()[0]
    return redirect(url_for("result", session_id=session_id))


# Below is the code to show the results page. It looks up the saved session, then shows the rule's numbered steps
# and whether "Did this fix it?" has been answered yet (None means not answered).
@app.get("/result/<int:session_id>")
def result(session_id):
    with connect() as conn:
        row = conn.execute(
            "SELECT s.rule_id, f.fixed FROM triage_sessions s "
            "LEFT JOIN feedback f ON f.session_id = s.id WHERE s.id = %s",
            (session_id,),
        ).fetchone()
    rule = find_rule(RULES, row[0]) if row else None
    if rule is None:
        abort(404)
    return render_template("result.html", rule=rule, session_id=session_id, fixed=row[1])


# Below is the code to save the Yes/No answer, linked to its session. Answering again replaces the old answer,
# and an answer for a session that does not exist is rejected (error 404).
@app.post("/result/<int:session_id>/feedback")
def feedback(session_id):
    answer = request.form.get("fixed")
    if answer not in ("yes", "no"):
        abort(400, description="Please answer Yes or No.")
    with connect() as conn:
        saved = conn.execute(
            "INSERT INTO feedback (session_id, fixed) SELECT id, %s FROM triage_sessions WHERE id = %s "
            "ON CONFLICT (session_id) DO UPDATE SET fixed = EXCLUDED.fixed, created_at = now() RETURNING id",
            (answer == "yes", session_id),
        ).fetchone()
    if saved is None:
        abort(404)
    return redirect(url_for("result", session_id=session_id))


# Below is the code to show the stats page. It counts the sessions in each category and the Yes answers
# in the database, then uses build_stats() to work out the totals and the fix rate.
@app.get("/stats")
def stats():
    with connect() as conn:
        category_counts = dict(
            conn.execute("SELECT category, COUNT(*) FROM triage_sessions GROUP BY category").fetchall()
        )
        fixed_count, answered_count = conn.execute(
            "SELECT COUNT(*) FILTER (WHERE fixed), COUNT(*) FROM feedback"
        ).fetchone()
    return render_template("stats.html", stats=build_stats(category_counts, fixed_count, answered_count))


# Below is the code to answer /health, which the pipeline and the monitoring call. It asks the database "SELECT 1":
# if the database answers it returns 200 (healthy), otherwise 503 (unhealthy).
@app.get("/health")
def health():
    try:
        with connect() as conn:
            conn.execute("SELECT 1")
    except psycopg.Error:
        return {"status": "error", "database": "unreachable", "environment": APP_ENV}, 503
    return {"status": "ok", "database": "connected", "environment": APP_ENV}


# Below is the code to answer /version with the environment name and the commit (SHA) the app was built from.
# The pipeline uses it to prove the same build reached Testing, Staging and Production.
@app.get("/version")
def version():
    return {"environment": APP_ENV, "version": APP_VERSION}


# Below is the code to add a Level 2 test page that returns a server error (500), to prove the 5xx alarm works.
# It acts as if it does not exist (404) unless the server's .env sets FAULT_INJECTION=1.
@app.get("/_fault/500")
def fault_error():
    if not FAULT_INJECTION:
        abort(404)
    return {"error": "simulated server error (FAULT_INJECTION=1)"}, 500


# Below is the code to add a Level 2 test page that answers slowly (up to 3 seconds), to prove the latency alarm works.
# It is also hidden (404) unless FAULT_INJECTION=1.
@app.get("/_fault/slow")
def fault_slow():
    if not FAULT_INJECTION:
        abort(404)
    delay_ms = max(0, min(request.args.get("ms", 800, type=int), 3000))
    time.sleep(delay_ms / 1000)
    return {"status": "ok", "slept_ms": delay_ms}


# Below is the code to run the app on your own computer with "python app.py" (the servers use Gunicorn instead).
# It creates the tables, then starts Flask's test server at http://127.0.0.1:5000 and reloads it after code changes.
if __name__ == "__main__":
    init_db()
    app.run(debug=True)
