# Below is the code to bring in the tools for these tests: json writes test rule files, runpy runs rules.py
# like a script, psycopg gives us its error type, and app_module and rules are the two files being tested.
import json
import runpy

import psycopg
import pytest

import app as app_module
import rules


# Below is the code to give each test a pretend browser (Flask's test client) that opens the app's pages
# without starting a real server.
@pytest.fixture
def client():
    return app_module.app.test_client()


# Below is the code to make sure a test never touches the database: if the app tries to connect, the test fails.
# Unit tests must work with no database at all.
@pytest.fixture
def no_database(monkeypatch):
    def refuse():
        raise AssertionError("unit tests must not use the database")

    monkeypatch.setattr(app_module, "connect", refuse)


# Below is the code to build a small, valid rule for tests that need one, with any field swapped out.
def make_rule(**changes):
    rule = {"id": "test-01", "category": "Test", "symptom": "Something broke", "steps": ["Step one", "Step two"]}
    rule.update(changes)
    return rule


# Below is the code to write a rule file into a temporary folder, so broken rules can be tested
# without touching the real rule files.
def write_rule_file(folder, name, text):
    (folder / name).write_text(text, encoding="utf-8")


# Below is the code to check the real rule files load and hold at least 20 rules, as the Project Brief requires.
def test_real_rules_load_with_at_least_20_rules():
    assert len(rules.load_rules()) >= 20


# Below is the code to check there are at least 5 categories, including the five named in the Project Brief.
def test_at_least_five_categories():
    names = rules.categories(rules.load_rules())
    assert len(names) >= 5
    assert {"Docker", "Git and GitHub", "Python", "Localhost and ports", "Network and setup"} <= set(names)


# Below is the code to check every real rule has an id, category, symptom and at least one step.
def test_every_real_rule_matches_the_schema():
    for rule in rules.load_rules():
        assert rules.check_rule(rule) == [], rule["id"]


# Below is the code to check no two real rules share the same id.
def test_rule_ids_are_unique():
    ids = [rule["id"] for rule in rules.load_rules()]
    assert len(ids) == len(set(ids))


# Below is the code to check categories are listed once each, in the order they first appear.
def test_categories_are_listed_once_in_order():
    sample = [make_rule(category="B"), make_rule(category="A"), make_rule(category="B")]
    assert rules.categories(sample) == ["B", "A"]


# Below is the code to check that choosing a category returns only that category's rules.
def test_rules_in_category_returns_only_that_category():
    docker = rules.rules_in_category(rules.load_rules(), "Docker")
    assert docker and all(rule["category"] == "Docker" for rule in docker)


# Below is the code to check an unknown category gives an empty list instead of an error.
def test_rules_in_unknown_category_is_empty():
    assert rules.rules_in_category(rules.load_rules(), "Nope") == []


# Below is the code to check a rule is found by its id and comes back with its own steps in the right order.
def test_find_rule_returns_the_right_steps_in_order():
    rule = rules.find_rule(rules.load_rules(), "docker-04")
    assert rule["symptom"] == "Container starts and then stops straight away"
    assert rule["steps"][0].startswith("Run 'docker ps -a'")
    assert rule["steps"][-1].startswith("Fix the error")


# Below is the code to check unknown symptom ids, including near misses, find nothing.
# This is how the app rejects symptoms that are not in the rule files.
@pytest.mark.parametrize("rule_id", ["nope-99", "", "DOCKER-04", "docker-4", None])
def test_find_rule_rejects_unknown_ids(rule_id):
    assert rules.find_rule(rules.load_rules(), rule_id) is None


# Below is the code to check a complete, valid rule passes the schema check with no problems.
def test_check_rule_accepts_a_valid_rule():
    assert rules.check_rule(make_rule()) == []


# Below is the code to check a rule missing one of its text fields is reported, naming the missing field.
@pytest.mark.parametrize("field", ["id", "category", "symptom"])
def test_check_rule_reports_a_missing_text_field(field):
    rule = make_rule()
    del rule[field]
    assert any(field in problem for problem in rules.check_rule(rule))


# Below is the code to check a text field made only of spaces counts as empty.
def test_check_rule_rejects_blank_text():
    assert rules.check_rule(make_rule(symptom="   ")) != []


# Below is the code to check bad steps are rejected: missing, an empty list, not a list, not text, or blank text.
@pytest.mark.parametrize("steps", [None, [], "Restart it", [1, 2], ["Step one", "  "]])
def test_check_rule_rejects_bad_steps(steps):
    assert any("steps" in problem for problem in rules.check_rule(make_rule(steps=steps)))


# Below is the code to check that something which is not a rule object at all is rejected.
@pytest.mark.parametrize("not_a_rule", ["text", 42, None, ["a", "list"]])
def test_check_rule_rejects_things_that_are_not_rules(not_a_rule):
    assert rules.check_rule(not_a_rule) != []


# Below is the code to check a rule file with broken JSON is reported by its file name instead of crashing.
def test_load_rules_reports_broken_json(tmp_path):
    write_rule_file(tmp_path, "bad.json", "[broken")
    with pytest.raises(ValueError, match="bad.json: not valid JSON"):
        rules.load_rules(tmp_path)


# Below is the code to check a rule file holding a single object, instead of a list of rules, is rejected.
def test_load_rules_reports_a_file_that_is_not_a_list(tmp_path):
    write_rule_file(tmp_path, "one.json", json.dumps(make_rule()))
    with pytest.raises(ValueError, match="must hold a list"):
        rules.load_rules(tmp_path)


# Below is the code to check two rules with the same id are caught.
def test_load_rules_reports_duplicate_ids(tmp_path):
    write_rule_file(tmp_path, "dup.json", json.dumps([make_rule(), make_rule(symptom="Another problem")]))
    with pytest.raises(ValueError, match="used more than once"):
        rules.load_rules(tmp_path)


# Below is the code to check a folder with no rule files fails loudly instead of starting an empty app.
def test_load_rules_fails_when_the_folder_is_empty(tmp_path):
    with pytest.raises(ValueError, match="no valid rules"):
        rules.load_rules(tmp_path)


# Below is the code to check valid rules spread over several files are all loaded, in file name order.
def test_load_rules_reads_every_json_file(tmp_path):
    write_rule_file(tmp_path, "a.json", json.dumps([make_rule(id="a-01")]))
    write_rule_file(tmp_path, "b.json", json.dumps([make_rule(id="b-01")]))
    assert [rule["id"] for rule in rules.load_rules(tmp_path)] == ["a-01", "b-01"]


# Below is the code to check the schema check command passes on the real rules and prints a summary.
def test_schema_check_passes_on_the_real_rules(capsys):
    assert rules.main() == 0
    assert "Rule check passed" in capsys.readouterr().out


# Below is the code to check the schema check command fails (returns 1) and lists the problems for broken rules.
def test_schema_check_fails_on_broken_rules(tmp_path, capsys):
    write_rule_file(tmp_path, "bad.json", json.dumps([make_rule(steps=[])]))
    assert rules.main(tmp_path) == 1
    assert "Rule check FAILED" in capsys.readouterr().out


# Below is the code to check that running "python rules.py" ends with exit code 0, so the pipeline step passes.
def test_running_rules_py_directly_exits_with_success():
    with pytest.raises(SystemExit) as finished:
        runpy.run_path(rules.__file__, run_name="__main__")
    assert finished.value.code == 0


# Below is the code to check the stats maths when nothing has been saved yet.
def test_stats_with_no_data():
    stats = app_module.build_stats({}, 0, 0)
    assert (stats["total"], stats["top_category"], stats["fix_rate"]) == (0, None, 0.0)


# Below is the code to check the total adds up the sessions from every category.
def test_stats_total_adds_up_every_category():
    assert app_module.build_stats({"Docker": 3, "Python": 4}, 0, 0)["total"] == 7


# Below is the code to check the most common category is the one with the most sessions.
def test_stats_most_common_category():
    counts = {"Docker": 2, "Python": 5, "Git and GitHub": 1}
    assert app_module.build_stats(counts, 0, 0)["top_category"] == "Python"


# Below is the code to check a tie for most common goes to the category first in the alphabet,
# so the answer never changes at random.
def test_stats_tie_goes_to_the_first_alphabetically():
    assert app_module.build_stats({"Python": 2, "Docker": 2}, 0, 0)["top_category"] == "Docker"


# Below is the code to check the fix rate: Yes answers out of all answers, as a percentage rounded to 1 decimal place.
@pytest.mark.parametrize(
    ("fixed", "answered", "expected"),
    [(1, 2, 50.0), (2, 3, 66.7), (1, 3, 33.3), (0, 4, 0.0), (5, 5, 100.0)],
)
def test_stats_fix_rate(fixed, answered, expected):
    assert app_module.build_stats({"Docker": answered}, fixed, answered)["fix_rate"] == expected


# Below is the code to check the home page opens and lists every category.
def test_home_page_lists_every_category(client, no_database):
    page = client.get("/").get_data(as_text=True)
    assert all(name in page for name in rules.categories(app_module.RULES))


# Below is the code to check that choosing a category lists its own symptoms and none from other categories.
def test_home_page_lists_the_chosen_categorys_symptoms(client, no_database):
    page = client.get("/?category=Docker").get_data(as_text=True)
    assert "Container starts and then stops straight away" in page
    assert "IndentationError or TabError when running a script" not in page


# Below is the code to check a made-up category gives a "not found" error (404).
def test_home_page_rejects_an_unknown_category(client, no_database):
    assert client.get("/?category=Nope").status_code == 404


# Below is the code to check unknown or missing symptoms are rejected (400) before anything is saved.
@pytest.mark.parametrize("form", [{"rule_id": "nope-99"}, {"rule_id": ""}, {}])
def test_triage_rejects_unknown_symptoms(client, no_database, form):
    assert client.post("/triage", data=form).status_code == 400


# Below is the code to check any answer other than Yes or No is rejected (400) before anything is saved.
@pytest.mark.parametrize("answer", ["maybe", "", "YES"])
def test_feedback_rejects_answers_other_than_yes_or_no(client, no_database, answer):
    assert client.post("/result/1/feedback", data={"fixed": answer}).status_code == 400


# Below is the code to check /version shows the environment name and the commit the app was built from.
def test_version_shows_environment_and_commit(client, monkeypatch):
    monkeypatch.setattr(app_module, "APP_ENV", "testing")
    monkeypatch.setattr(app_module, "APP_VERSION", "abc123")
    assert client.get("/version").get_json() == {"environment": "testing", "version": "abc123"}


# Below is the code to check /health reports 503 and "unreachable" when the database cannot be reached.
def test_health_reports_503_when_the_database_is_down(client, monkeypatch):
    def broken_connect():
        raise psycopg.OperationalError("database is down")

    monkeypatch.setattr(app_module, "connect", broken_connect)
    response = client.get("/health")
    assert response.status_code == 503
    assert response.get_json()["database"] == "unreachable"


# Below is the code to check the Level 2 test pages stay hidden (404) while FAULT_INJECTION is off.
@pytest.mark.parametrize("path", ["/_fault/500", "/_fault/slow"])
def test_fault_pages_are_hidden_when_switched_off(client, monkeypatch, path):
    monkeypatch.setattr(app_module, "FAULT_INJECTION", False)
    assert client.get(path).status_code == 404


# Below is the code to check the error test page returns a 500 error once FAULT_INJECTION is switched on.
def test_fault_error_page_works_when_switched_on(client, monkeypatch):
    monkeypatch.setattr(app_module, "FAULT_INJECTION", True)
    assert client.get("/_fault/500").status_code == 500


# Below is the code to check the slow test page waits the time asked, kept between 0 and 3000 ms (800 if not a number).
# The waiting is faked, so this test still runs instantly.
@pytest.mark.parametrize(("ms", "expected"), [("250", 250), ("99999", 3000), ("-5", 0), ("abc", 800)])
def test_fault_slow_page_limits_the_delay(client, monkeypatch, ms, expected):
    monkeypatch.setattr(app_module, "FAULT_INJECTION", True)
    waits = []
    monkeypatch.setattr(app_module.time, "sleep", waits.append)
    assert client.get(f"/_fault/slow?ms={ms}").get_json()["slept_ms"] == expected
    assert waits == [expected / 1000]


# Below is the code to check every page shows which environment it is running in (the coloured badge).
def test_pages_show_the_environment_badge(client, no_database):
    assert f"env-{app_module.APP_ENV}" in client.get("/").get_data(as_text=True)


# Below is the code to check a page that does not exist gives a "not found" error (404).
def test_unknown_page_is_404(client):
    assert client.get("/no-such-page").status_code == 404
