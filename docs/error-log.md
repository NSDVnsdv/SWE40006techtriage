# Error log

Record every problem as it happens: the final report has a whole section for
troubleshooting. Add the screenshot or log file name in the Evidence column.

| # | Date | Who | Level / step | What broke (exact error text) | What we tried | What fixed it | Evidence |
|---|---|---|---|---|---|---|---|
| 1 | 2026-10-18 | Murtaza | L2 / AWS access | EC2 console showed no instances | Checked region (us-east-1) | Servers live in Sy Dam's Learner Lab account; used his temporary lab credentials via a federation sign-in link (never committed) | - |
| 2 | 2026-10-18 | Murtaza | L2 / step 3 | "Error establishing SSH connection to your instance" | - | Used the Session Manager tab, not EC2 Instance Connect (port 22 is closed by design) | - |
| 3 | 2026-10-18 | Murtaza | L2 / step 1 | `git push` said "Total 0", PR had no changes | Re-ran checkout | Branch already existed so the patch landed on main; `git branch -f feature/level2-monitoring main`, push, `git reset --hard origin/main` | - |
| 4 | 2026-10-18 | Murtaza | L2 / step 9 | First memory test peaked at ~75%, alarm (80%) did not fire | - | Script used MemAvailable; agent uses total-free-buffers-cached. Recalculated with the agent formula (target 88%), reached ~83.5%, alarm fired | L2-13 |
| 5 | 2026-10-18 | Murtaza | L2 / step 9 | Memory retry still did not fire | - | Commands had been pasted into CloudShell, not Production; re-ran on Production | - |
| 6 | 2026-10-18 | Murtaza | L2 / step 9 | `cw-status.sh`: "Unknown options: --alarm-name-prefix" | - | describe-alarm-history has no prefix option; filter with a JMESPath starts_with query (fixed in repo) | - |
| 7 | 2026-10-20 | Saffan | L3 / A10 | `docker compose up` on the PC: "required variable APP_ENV is missing a value" (also DB_PASSWORD and GHCR_OWNER) | - | These are compose.yaml's own safety checks: the PC had no .env. Created one from .env.example (PC only, ignored by git) | - |
| 8 | 2026-10-20 | Saffan | L3 / B3 | Coverage report showed only 71% and listed Flask's `app.py` and Werkzeug's `rules.py` | Read the coverage table | `include = ["app.py", "rules.py"]` also matched library files with the same names. Changed to `source_pkgs = ["app", "rules"]`: 98.6% total, rules.py 100% | CI test job log |
| 9 | 2026-10-20 | Saffan | L3 / C4 | actionlint: "SC2034:warning: attempt appears unused" in deploy.yml | - | Renamed the unused loop variable to `_`. actionlint and shellcheck clean | - |
| 10 | 2026-10-20 | Saffan | L3 / C3 | Learner Lab terminal: "An error occurred (AuthFailure) when calling the DescribeInstances operation: AWS was not able to validate the provided access credentials" | Re-ran the command | The terminal on the lab page held old keys. Ran the commands in AWS CloudShell (from the console) instead | - |
| 11 | 2026-10-20 | Saffan, Sy Dam | L3 / C6 | Deploy run #1 stopped: "Add an INSTANCE_ID variable to the 'development' GitHub environment" | Read the environment variables through the GitHub API | They were named DEVELOPMENT_ID, TESTING_ID, STAGING_ID and PRODUCTION_ID. Renamed all 4 to INSTANCE_ID. The workflow stopped before touching AWS | Deploy run #1 |
| 12 | 2026-10-20 | Saffan, Sy Dam | L3 / C6 | Deploy run #2, "Log in to AWS": "The security token included in the request is invalid." | Checked the secrets' save times: only 7 minutes old, so not expired | The values had been pasted wrongly. Re-pasted only the part after "=" for all 3, copied from one AWS Details view. Runs #3 to #6 logged in and deployed | Deploy runs #2 and #3 |
| 13 | 2026-10-20 | Saffan | L3 / E6 | A comments-only commit was pushed to the already merged `feature/level3-app` branch instead of a new `feature/level3-docs` branch | - | The push helper script had the branch name written into it. It now requires the branch name every time. No effect on develop, main or the servers | - |
