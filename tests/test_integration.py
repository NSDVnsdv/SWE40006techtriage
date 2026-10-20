# Below is the code to bring in the tools for these tests: os reads settings, psycopg talks to the real database,
# pytest runs the tests, and app_module is the app being tested.
import os

import psycopg
import pytest

import app as app_module


# Below is the code to point the app at a real, throwaway PostgreSQL database and empty its tables before each test.
# The address comes from TEST_DATABASE_URL: without it these tests are skipped on a PC, but fail in GitHub Actions.
@pytest.fixture
def database(monkeypatch):
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        if os.environ.get("CI"):
            pytest.fail("TEST_DATABASE_URL must be set in the pipeline")
        pytest.skip("set TEST_DATABASE_URL to a throwaway PostgreSQL database to run the integration tests")
    monkeypatch.setattr(app_module, "DATABASE_URL", url)
    app_module.init_db()
    with psycopg.connect(url) as conn:
        conn.execute("TRUNCATE feedback, triage_sessions RESTART IDENTITY")
    return url


# Below is the code to give each test a pretend browser connected to the app and its real database.
@pytest.fixture
def client(database):
    return app_module.app.test_client()


# Below is the code to run one SQL query on the test database and return every row it finds.
def query(database, sql, *params):
    with psycopg.connect(database) as conn:
        return conn.execute(sql, params).fetchall()


# Below is the code to pick a symptom the way a user would, and return the new session's number from the page address.
def start_session(client, rule_id):
    response = client.post("/triage", data={"rule_id": rule_id})
    return int(response.headers["Location"].rsplit("/", 1)[1])


# Below is the code to check that starting the app creates both tables in the database.
def test_init_db_creates_both_tables(database):
    rows = query(database, "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
    assert {"triage_sessions", "feedback"} <= {row[0] for row in rows}


# Below is the code to check that creating the tables again (as happens on every app restart) keeps saved data.
def test_init_db_again_keeps_existing_data(client, database):
    start_session(client, "docker-01")
    app_module.init_db()
    assert query(database, "SELECT COUNT(*) FROM triage_sessions") == [(1,)]


# Below is the code to check picking a symptom saves a session with its category, symptom and rule id,
# then sends the user to that session's results page.
def test_picking_a_symptom_saves_a_session(client, database):
    response = client.post("/triage", data={"rule_id": "git-02"})
    assert response.status_code == 302
    assert response.headers["Location"].endswith("/result/1")
    assert query(database, "SELECT category, symptom, rule_id FROM triage_sessions") == [
        ("Git and GitHub", "Merge conflict after git pull or git merge", "git-02")
    ]


# Below is the code to check the results page reads the saved session back and shows its steps and the Yes/No question.
def test_results_page_shows_the_saved_rule(client):
    session_id = start_session(client, "python-04")
    page = client.get(f"/result/{session_id}").get_data(as_text=True)
    assert "IndentationError or TabError when running a script" in page
    assert "Go to the line number shown in the error." in page
    assert "Did this fix it?" in page


# Below is the code to check a Yes answer is saved in the database, linked to its session, and read back on the page.
def test_yes_answer_is_saved_and_read_back(client, database):
    session_id = start_session(client, "docker-02")
    assert client.post(f"/result/{session_id}/feedback", data={"fixed": "yes"}).status_code == 302
    assert query(database, "SELECT session_id, fixed FROM feedback") == [(session_id, True)]
    assert "Yes, it is fixed" in client.get(f"/result/{session_id}").get_data(as_text=True)


# Below is the code to check a No answer is saved too, and the page then shows the "not fixed" message.
def test_no_answer_is_saved_and_read_back(client, database):
    session_id = start_session(client, "network-04")
    client.post(f"/result/{session_id}/feedback", data={"fixed": "no"})
    assert query(database, "SELECT fixed FROM feedback WHERE session_id = %s", session_id) == [(False,)]
    assert "No, still not fixed" in client.get(f"/result/{session_id}").get_data(as_text=True)


# Below is the code to check that answering again replaces the first answer, so a session is never counted twice.
def test_answering_again_replaces_the_answer(client, database):
    session_id = start_session(client, "ports-01")
    client.post(f"/result/{session_id}/feedback", data={"fixed": "yes"})
    client.post(f"/result/{session_id}/feedback", data={"fixed": "no"})
    assert query(database, "SELECT fixed FROM feedback") == [(False,)]


# Below is the code to check feedback for a session that does not exist is rejected (404) and nothing is saved.
def test_feedback_for_a_missing_session_is_rejected(client, database):
    assert client.post("/result/999/feedback", data={"fixed": "yes"}).status_code == 404
    assert query(database, "SELECT COUNT(*) FROM feedback") == [(0,)]


# Below is the code to check the database itself refuses a feedback row that is not linked to a real session.
def test_database_refuses_feedback_without_a_session(database):
    with pytest.raises(psycopg.errors.ForeignKeyViolation), psycopg.connect(database) as conn:
        conn.execute("INSERT INTO feedback (session_id, fixed) VALUES (999, true)")


# Below is the code to check a results page for a session that does not exist gives "not found" (404).
def test_results_page_for_a_missing_session_is_404(client):
    assert client.get("/result/999").status_code == 404


# Below is the code to check the stats page counts real saved data: 3 sessions (2 Git, 1 Docker)
# with one Yes and one No answer should show Git and GitHub as most common and a 50% fix rate.
def test_stats_page_counts_saved_sessions_and_answers(client):
    first = start_session(client, "git-01")
    second = start_session(client, "git-03")
    start_session(client, "docker-05")
    client.post(f"/result/{first}/feedback", data={"fixed": "yes"})
    client.post(f"/result/{second}/feedback", data={"fixed": "no"})
    page = client.get("/stats").get_data(as_text=True)
    assert 'id="total-sessions">3<' in page
    assert 'id="top-category">Git and GitHub<' in page
    assert 'id="fix-rate">50.0%<' in page


# Below is the code to check the stats page still works when the database has no sessions yet.
def test_stats_page_with_no_sessions(client):
    page = client.get("/stats").get_data(as_text=True)
    assert 'id="total-sessions">0<' in page
    assert "None yet" in page


# Below is the code to check /health returns 200 and "connected" when the real database answers.
def test_health_is_200_with_the_database(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["database"] == "connected"


# Below is the code to check /health returns 503 and "unreachable" without a database,
# by pointing the app at a port where no database is running.
def test_health_is_503_without_the_database(client, monkeypatch):
    monkeypatch.setattr(app_module, "DATABASE_URL", "postgresql://techtriage:wrong@127.0.0.1:1/techtriage")
    response = client.get("/health")
    assert response.status_code == 503
    assert response.get_json()["database"] == "unreachable"
