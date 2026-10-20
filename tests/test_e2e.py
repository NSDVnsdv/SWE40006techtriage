# Below is the code to bring in the tools for these browser tests: os reads the expected environment and commit,
# re matches page titles, and Playwright drives a real web browser.
import os
import re

import pytest
from playwright.sync_api import Page, expect


# Below is the code to skip these tests unless a website address is given, for example:
# pytest tests/test_e2e.py --base-url http://<Testing server address>
@pytest.fixture(autouse=True)
def needs_base_url(base_url):
    if not base_url:
        pytest.skip("browser tests need --base-url pointing at a running TechTriage site")


# Below is the code to do a full troubleshooting run like a real user: open the site, pick a category,
# pick a symptom, check the numbered steps appear, then click Yes or No.
def run_triage(page, category, symptom, answer):
    page.goto("/")
    page.get_by_role("link", name=category).click()
    page.get_by_role("button", name=symptom).click()
    expect(page.locator("ol.steps li").first).to_be_visible()
    page.get_by_role("button", name=answer, exact=True).click()


# Below is the code to check the home page opens with the TechTriage title and all 5 category cards.
def test_home_page_shows_the_categories(page: Page):
    page.goto("/")
    expect(page).to_have_title(re.compile("TechTriage"))
    expect(page.locator(".category-card")).to_have_count(5)


# Below is the code to check a full run that ends in Yes is saved, and is still shown after reloading the page.
def test_full_run_answering_yes_is_saved(page: Page):
    run_triage(page, "Docker", "Container starts and then stops straight away", "Yes")
    expect(page.get_by_role("status")).to_contain_text("Yes, it is fixed")
    page.reload()
    expect(page.get_by_role("status")).to_contain_text("Yes, it is fixed")


# Below is the code to check a full run that ends in No is saved too, and shows the "not fixed" message.
def test_full_run_answering_no_is_saved(page: Page):
    run_triage(page, "Git and GitHub", "Merge conflict after git pull or git merge", "No")
    expect(page.get_by_role("status")).to_contain_text("No, still not fixed")


# Below is the code to check the results page shows the chosen rule's steps, numbered and in the right order.
def test_results_page_shows_numbered_steps(page: Page):
    page.goto("/?category=Python")
    page.get_by_role("button", name="IndentationError or TabError when running a script").click()
    steps = page.locator("ol.steps li")
    expect(steps).to_have_count(4)
    expect(steps.first).to_have_text("Go to the line number shown in the error.")


# Below is the code to check the stats page counts a new session: its total goes up by one after a full run.
def test_stats_page_counts_a_new_session(page: Page):
    page.goto("/stats")
    before = int(page.locator("#total-sessions").inner_text())
    run_triage(page, "Network and setup", "Website name cannot be found (DNS error)", "Yes")
    page.goto("/stats")
    expect(page.locator("#total-sessions")).to_have_text(str(before + 1))


# Below is the code to check /health answers 200 and says the database is connected.
def test_health_says_the_database_is_connected(page: Page):
    response = page.goto("/health")
    assert response.status == 200
    assert response.json()["database"] == "connected"


# Below is the code to check /version shows a commit, and the exact environment and commit
# when the pipeline passes them in as EXPECTED_ENV and EXPECTED_SHA.
def test_version_shows_the_expected_environment_and_commit(page: Page):
    response = page.goto("/version")
    version = response.json()
    assert response.status == 200 and version["version"]
    if os.environ.get("EXPECTED_ENV"):
        assert version["environment"] == os.environ["EXPECTED_ENV"]
    if os.environ.get("EXPECTED_SHA"):
        assert version["version"] == os.environ["EXPECTED_SHA"]
