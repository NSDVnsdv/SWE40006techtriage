#!/bin/bash
# Below is the code to create the level-1 to level-4 labels and one GitHub issue per Level 1 section. Needs the GitHub CLI
# (winget install --id GitHub.cli -e, then gh auth login). Run from the repo folder in Git Bash: bash scripts/create-issues.sh

# Below is the code to stop the script at the first error.
set -euo pipefail

# Below is the code to create the 4 level labels (or update them if they already exist).
gh label create level-1 --color 1d76db --description "Level 1: pipeline infrastructure" --force
gh label create level-2 --color d93f0b --description "Level 2: Production monitoring and alarms" --force
gh label create level-3 --color 0e8a16 --description "Level 3: TechTriage app, tests, deployment" --force
gh label create level-4 --color 5319e7 --description "Level 4: full automation and demo" --force

# Below is the code to create one issue with the level-1 label. Its inputs are the title and the checklist text.
issue() { gh issue create --label level-1 --title "$1" --body "$2"; }

# Below is the code to create the 8 Level 1 issues (A to H), each with a checklist of the steps it covers.
# Level 2 to 4 issues are added later from their own level files.
issue "L1-A: Agree names (repo, environments, AWS region)" "Level 1 steps 1.
- [ ] Repo: SWE40006techtriage (image name: swe40006techtriage)
- [ ] Environments: development, testing, staging, production
- [ ] One AWS region for everything (us-east-1)
- [ ] Names written in README"

issue "L1-B: Create public repo, add collaborators, push starter files" "Level 1 steps 2-5 (brief 8.1).
- [ ] Public repo SWE40006techtriage created (empty, no README/licence)
- [ ] 3 teammates added as collaborators and invites accepted
- [ ] Starter files pushed to main
- [ ] develop branch created from main"

issue "L1-C: First green CI run and public GHCR package" "Level 1 steps 6-7.
- [ ] CI run on main is green (build + push to GHCR)
- [ ] Package swe40006techtriage visibility changed to Public
- [ ] Anonymous docker pull works"

issue "L1-D: Lock the repo down (branch protection, secret scanning)" "Level 1 steps 8-11 (brief 8.1).
- [ ] main and develop protected: PR required, 1 approval, build check required, no force-push
- [ ] Secret scanning and push protection On
- [ ] Rules tested with a feature branch PR and a rejected direct push
- [ ] Issue backlog created with level-1..level-4 labels"

issue "L1-E: AWS account setup (budget, SSM role, security group)" "Level 1 steps 12-14 (brief 8.2).
- [ ] Budget alert (US\$20) emailing the team, or Learner Lab spend screenshot
- [ ] SSM instance role ready (AmazonSSMManagedInstanceCore / LabInstanceProfile)
- [ ] Security group techtriage-web: inbound HTTP 80 only, no 22, no 5432"

issue "L1-F: Launch the four EC2 servers" "Level 1 steps 15-17 (brief 9.2).
- [ ] techtriage-development
- [ ] techtriage-testing
- [ ] techtriage-staging
- [ ] techtriage-production
- [ ] All Running with status checks passed
- [ ] Elastic IP attached to Production"

issue "L1-G: Prove repo -> CI -> GHCR -> servers connects" "Level 1 steps 18-21.
- [ ] Fleet Manager shows all 4 Online
- [ ] Session Manager on each: docker --version, docker compose version, docker compose ps
- [ ] Each placeholder page shows its own environment and commit SHA
- [ ] Commit SHA on pages matches the GitHub Actions run"

issue "L1-H: Hand over Level 1" "Level 1 steps 22-24.
- [ ] README: server table, Session Manager login, branch rules, what Level 3 replaces
- [ ] Repo link, 4 addresses and README sent to the team
- [ ] Development, Testing, Staging stopped when idle"

# Below is the code to print where to find the new issues.
echo "Done. Open the Issues tab and filter by label:level-1."
