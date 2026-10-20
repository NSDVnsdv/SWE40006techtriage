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
