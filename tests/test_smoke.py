# Below is the code to bring in the tools for the smoke tests: json and urllib call the live site directly
# (no browser needed), os reads the expected commit, and pytest runs the tests.
import json
import os
import urllib.request

import pytest


# Below is the code to skip these tests unless a website address is given, for example:
# pytest tests/test_smoke.py --base-url http://<Staging or Production address>
@pytest.fixture(autouse=True)
def needs_base_url(base_url):
    if not base_url:
        pytest.skip("smoke tests need --base-url pointing at a running TechTriage site")


# Below is the code to open one page of the live site and return its status code and JSON contents.
# Any error status (such as 503) makes the test fail straight away.
def get_json(base_url, path):
    with urllib.request.urlopen(base_url.rstrip("/") + path, timeout=10) as response:
        return response.status, json.load(response)


# Below is the code to run smoke test 1: /health must answer 200 and say the database is connected.
def test_health_reports_the_database_is_connected(base_url):
    status, body = get_json(base_url, "/health")
    assert status == 200
    assert body["database"] == "connected"


# Below is the code to run smoke test 2: /version must show the commit the pipeline just deployed (EXPECTED_SHA),
# and the right environment name when EXPECTED_ENV is given. This proves the same image reached this server.
def test_version_is_the_expected_commit(base_url):
    if not os.environ.get("EXPECTED_SHA"):
        pytest.fail("set EXPECTED_SHA to the commit that was deployed")
    status, body = get_json(base_url, "/version")
    assert status == 200
    assert body["version"] == os.environ["EXPECTED_SHA"]
    if os.environ.get("EXPECTED_ENV"):
        assert body["environment"] == os.environ["EXPECTED_ENV"]
