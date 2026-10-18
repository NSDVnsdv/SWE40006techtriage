# Level 1 runbook: Pipeline infrastructure

Every Level 1 step in order, with exact values, where to click, and what to
capture. Step numbers match the Level 1 task file, and brackets like (8.1) are
Table 10 steps in the Project Brief.

**For every step: take a screenshot AND copy the terminal/log text.** If
anything breaks, write it in [error-log.md](error-log.md) straight away.

Legend: `[x]` done, `[ ]` to do.

---

## 0. Already done locally

- [x] Starter files written: `README.md`, `.gitignore`, `.gitattributes`,
      `.dockerignore`, `Dockerfile`, `placeholder/server.py`, `compose.yaml`,
      `server-setup.sh`, `.github/workflows/ci.yml`, `scripts/create-issues.sh`,
      `docs/LEVEL1-STEPS.md`, `docs/error-log.md`
- [x] Image builds locally; `docker compose up` shows the app `Up (healthy)`;
      `/`, `/health`, `/version` return the right environment and SHA; unknown
      paths return 404; the container stops in about 1 second
- [x] `compose.yaml` refuses to start if `APP_ENV`/`GHCR_OWNER` are missing
- [x] `server-setup.sh` passes `shellcheck`; `ci.yml` passes `actionlint`
- [x] `server-setup.sh` install steps tested in an `amazonlinux:2023`
      container: Docker 25.0.14 + Docker Compose v2.40.3 install and work
- [x] Local git repo: `main` with the initial commit, `develop` branched from it.
      **Nothing has been pushed to GitHub yet.**

## Record sheet (fill in as you go)

| Item | Value |
|---|---|
| GitHub owner (username or org) | `NSDVnsdv` |
| Repo URL | https://github.com/NSDVnsdv/SWE40006techtriage |
| Commit SHA on `main` (`git rev-parse main`) | |
| First green CI run URL | |
| GHCR image | `ghcr.io/nsdvnsdv/swe40006techtriage:latest` |
| AWS region | `us-east-1` |
| Security group ID | `sg-...` |
| development instance ID / IP | |
| testing instance ID / IP | |
| staging instance ID / IP | |
| production instance ID / Elastic IP | |

---

## A. Agree the basics

### Step 1: Agree names
- [ ] Confirm with the team: repo `SWE40006techtriage` (Docker image name
      `swe40006techtriage`); environments `development`,
      `testing`, `staging`, `production`; region `us-east-1`.
      These are already in the README's "Agreed names" table. If the team
      picks another region, change it there.

---

## B. Code repository (GitHub) (8.1)

### Step 2: Create the public repo
- [ ] github.com -> **+** (top right) -> **New repository**
  - Owner: you (or the team's org)
  - Repository name: `SWE40006techtriage`
  - Visibility: **Public**
  - Do **NOT** tick "Add a README", ".gitignore" or "licence". The repo must be
    empty or the first push will be rejected.
- [ ] **Create repository**. Write the owner in the record sheet.
- [ ] Recommended: GitHub -> Settings -> **Emails** -> add
      `104681360@student.swin.au.edu` (the email your local git commits use),
      so commits count on your profile as contribution evidence.

### Step 3: Add collaborators
- [ ] Repo -> **Settings** -> **Collaborators** -> **Add people** -> add
      Saffan, Tyler and Murtaza by GitHub username.
- [ ] Ask them to accept the email invite. They can't review PRs until they do.

### Step 4: Push the starter files to `main`
In PowerShell or Git Bash, from the project folder:

```bash
cd C:\Users\nvha2\Downloads\SWE40006\project
git remote add origin https://github.com/NSDVnsdv/SWE40006techtriage.git
git push -u origin main
```

- [ ] If a browser window asks you to sign in to GitHub, do it (Git Credential
      Manager). GitHub no longer accepts account passwords on the command line.
- [ ] Push **only `main`** first, so `main` becomes the default branch and the
      first CI run publishes the `:latest` image.

### Step 5: Create `develop`
`develop` already exists locally (made from `main`), so just push it:

```bash
git push -u origin develop
```

- [ ] Check the repo's branch dropdown shows `main` and `develop`.
      Team rule from now on: `feature/...` -> PR into `develop` -> release PR
      `develop` -> `main`.

---

## C. CI/build server (GitHub Actions)

### Step 6: Watch the first run go green
- [ ] Repo -> **Actions** tab -> the **CI** run for `main` -> wait for the
      green tick (usually 1-2 minutes).
- [ ] Open the run -> **build** job. The **Summary** page shows the commit SHA
      and the tags pushed (`...:<sha>` and `...:latest`).
- [ ] Copy the log: in the job view, gear icon -> **View raw logs** (or
      **Download log archive**). Write the run URL and SHA in the record sheet.

### Step 7: Make the GHCR package public
- [ ] Your avatar (top right) -> **Your profile** -> **Packages** tab ->
      **swe40006techtriage**. For an org repo it's the org's **Packages** tab.
- [ ] **Package settings** (bottom of right sidebar) -> **Danger Zone** ->
      **Change visibility** -> **Public** -> type `swe40006techtriage` -> confirm.
      It may already be **Public** (packages from a public repo usually take
      its visibility). If so, there is nothing to change: just screenshot the
      package page showing "Public".
- [ ] Still in Package settings, check **Manage Actions access** lists the
      `SWE40006techtriage` repo (it is linked automatically by the image label).
- [ ] Prove an anonymous pull works (Docker Desktop running):

```bash
docker logout ghcr.io
docker pull ghcr.io/nsdvnsdv/swe40006techtriage:latest
```

> The servers download the image with no password, so if this pull fails, the
> servers in section F will fail too.

---

## D. Lock the repo down (8.1)

### Step 8: Protect `main` and `develop`
The `build` check only appears in the list after it has run once (step 6).

- [ ] Repo -> **Settings** -> **Branches** -> **Add classic branch protection rule**
  - Branch name pattern: `main`
  - [x] **Require a pull request before merging** -> Required approvals: **1**
  - [x] **Require status checks to pass before merging** -> search `build` -> select it
  - [x] **Do not allow bypassing the above settings** (otherwise you, as the
        owner, could still push directly)
  - Leave **Allow force pushes** and **Allow deletions** unticked
  - **Create**
- [ ] Repeat with pattern `develop`.

(The newer **Rulesets** page can do the same: target `main` and `develop`,
"Require a pull request" with 1 approval, "Require status checks" -> `build`,
"Block force pushes".)

### Step 9: Secret scanning and push protection
- [ ] Repo -> **Settings** -> **Advanced Security** (called "Code security" on
      some accounts) -> check **Secret scanning** / **Secret Protection** is
      **Enabled** and **Push protection** is **Enabled**. Public repos usually
      have both on already. Screenshot either way.

### Step 10: Test the rules
Open a PR that should be blocked until a teammate approves it:

```bash
git checkout develop
git pull
git checkout -b feature/test-branch-protection
# make a tiny edit, e.g. add your name under "Agreed names" in README.md
git commit -am "Test branch protection"
git push -u origin feature/test-branch-protection
```

- [ ] On GitHub: **Compare & pull request** -> **base: develop** -> create PR.
- [ ] Screenshot the PR while it shows the `build` check running and merging
      blocked ("Review required").
- [ ] Ask a teammate to approve it (you cannot approve your own), then merge.

Prove that pushing straight to the branch is rejected:

```bash
git checkout develop
git pull
git commit --allow-empty -m "Direct push test (should be rejected)"
git push            # expect: "protected branch hook declined"
git reset --hard origin/develop   # throws away only that empty test commit
```

- [ ] Screenshot and copy the rejection message.

### Step 11: Issue backlog
Option A (script, about 1 minute): needs the GitHub CLI.

```bash
winget install --id GitHub.cli -e      # then reopen the terminal
gh auth login                          # GitHub.com -> HTTPS -> browser
bash scripts/create-issues.sh          # from the project folder, in Git Bash
```

Option B (by hand): create one issue per section A-H of this file, labelled
`level-1`. The titles and checklists are in `scripts/create-issues.sh`.

- [ ] Labels `level-1`, `level-2`, `level-3`, `level-4` exist.
- [ ] Level 1 issues created. Add Level 2-4 issues from their level files
      when you get to them.
- [ ] Screenshot the Issues tab.

---

## E. AWS account setup (8.2)

On AWS Academy Learner Lab: **Start Lab** -> wait for the green dot -> click
**AWS**. Set the region (top right) to **N. Virginia (us-east-1)** and keep it
there for every step.

### Step 12: Budget alert
- [ ] **Billing and Cost Management** -> **Budgets** -> **Create budget** ->
      **Use a template** -> **Monthly cost budget**
  - Name: `techtriage-monthly`, amount: `20` (USD)
  - Email recipients: all four team emails
  - **Create budget**
- [ ] If Budgets is blocked (normal on Learner Lab), screenshot the lab's
      spending display ("Used $X of $Y") instead, and note that in the error log.

### Step 13: Systems Manager role for the servers
- **Learner Lab:** nothing to create. Pick **LabInstanceProfile** when launching (step 15).
- **Normal AWS account:**
  - [ ] **IAM** -> **Roles** -> **Create role** -> Trusted entity **AWS service**,
        use case **EC2** -> Next
  - [ ] Permissions: tick **AmazonSSMManagedInstanceCore** -> Next
  - [ ] Role name: `techtriage-ec2-ssm` -> **Create role**
- [ ] Screenshot the role/profile and its permissions (this is the "IAM policy" evidence for 8.2).

### Step 14: Security group `techtriage-web`
- [ ] **EC2** -> **Security Groups** -> **Create security group**
  - Name: `techtriage-web`
  - Description: `TechTriage web - HTTP 80 only`
  - VPC: the default VPC
  - **Inbound rules** -> **Add rule** -> Type **HTTP** (port 80) -> Source **Anywhere-IPv4** (`0.0.0.0/0`)
  - **No** SSH (22), **no** PostgreSQL (5432), nothing else
  - **Outbound rules**: leave the default (All traffic). Servers need it to
    download Docker, Compose and the image.
  - **Create security group**
- [ ] Write the `sg-...` ID in the record sheet. Screenshot the **Inbound rules** tab.

---

## F. The four servers (EC2) (9.2)

### Step 15: Launch 4 instances (repeat 4 times)

| Server | Name tag | Environment tag | `ENV_NAME=` in user data |
|---|---|---|---|
| 1 | `techtriage-development` | `development` | `development` |
| 2 | `techtriage-testing` | `testing` | `testing` |
| 3 | `techtriage-staging` | `staging` | `staging` |
| 4 | `techtriage-production` | `production` | `production` |

**Prepare the user data first:** open `server-setup.sh`, copy it into Notepad
and change the one line at the top (owner and repo are already filled in):

```bash
ENV_NAME="development"     # change per server (table above)
```

Then **EC2** -> **Instances** -> **Launch instances**:

- [ ] **Name and tags:** Name = `techtriage-<env>` -> **Add additional tags** ->
      Key `Environment`, Value `<env>`
- [ ] **AMI:** Amazon Linux 2023 (the default, 64-bit x86)
- [ ] **Instance type:** `t3.micro`
- [ ] **Key pair:** **Proceed without a key pair**
- [ ] **Network settings** -> **Edit**:
  - Auto-assign public IP: **Enable**
  - Firewall: **Select existing security group** -> `techtriage-web`
- [ ] **Storage:** leave the default (8 GiB gp3)
- [ ] **Advanced details**:
  - **IAM instance profile:** `LabInstanceProfile` (Learner Lab) or `techtriage-ec2-ssm`
  - **User data:** paste your edited `server-setup.sh`
- [ ] **Launch instance**

Repeat for testing, staging and production, changing **only** the Name tag,
Environment tag and `ENV_NAME`.

### Step 16: Wait for them to come up
- [ ] Instance state **Running** and status checks **2/2 passed** (newer consoles show 3/3).
- [ ] Allow another 2-3 minutes after that for the user data to finish
      installing Docker and starting the app.
- [ ] Screenshot the instance list with the **Name** and **Environment** tags
      visible. Use the gear icon to add the `Environment` tag column.

### Step 17: Elastic IP for Production (recommended)
- [ ] **EC2** -> **Elastic IPs** -> **Allocate Elastic IP address** -> **Allocate**
- [ ] Select it -> **Actions** -> **Associate Elastic IP address** -> Instance:
      `techtriage-production` -> **Associate**
- [ ] Production's address is now the Elastic IP for good (Level 2's uptime
      check needs this). Record it.
- An Elastic IP is billed while the instance is stopped too. Release it at the
  end of the project.

---

## G. Prove everything connects

### Step 18: Fleet Manager
- [ ] **Systems Manager** -> **Fleet Manager** (left menu) -> all 4 servers
      listed with ping status **Online**.
- If one is missing after about 10 minutes: EC2 -> select it -> **Actions** ->
  **Security** -> **Modify IAM role** -> attach the profile -> **Instance state**
  -> **Reboot**.

### Step 19: Session Manager on each server
- [ ] EC2 -> select the server -> **Connect** -> **Session Manager** tab -> **Connect**, then run:

```bash
sudo -i                      # sessions start as ssm-user, who can't use docker
docker --version
docker compose version
cd /opt/techtriage
docker compose ps            # expect: techtriage-app-1 ... Up ... (healthy)
cat .env
curl -s localhost/version; echo
tail -n 5 /var/log/techtriage-setup.log
```

- [ ] Screenshot and copy the output for **each** of the 4 servers.

### Step 20: Each placeholder page in the browser
- [ ] Open `http://<public IP>` for each server. Type `http://` yourself,
      because the page has no HTTPS. Each page has its own colour:
      development blue, testing amber, staging purple, production green.
- [ ] Also open `http://<public IP>/version`.
- [ ] Screenshot all 4 (with the address bar visible).

### Step 21: Match the commit ID
- [ ] Compare these three; they must be identical:
  1. The **Commit (SHA)** on each server's page
  2. The commit in the green Actions run for `main` (step 6 Summary)
  3. `git rev-parse origin/main` on your machine
- [ ] Screenshot them side by side. This proves repo -> CI -> GHCR -> servers
      is one connected chain.

> Do steps 20-21 **before** merging anything new into `main`. A new `main`
> build moves `:latest`, but the servers only pick it up when you run
> `docker compose pull && docker compose up -d` on them (Level 4 automates this).

---

## H. Hand over

### Step 22: Fill in the README
- [ ] On a `feature/readme-servers` branch, fill in the **Servers** table
      (instance IDs and addresses) and confirm the region. PR into `develop`,
      get it approved and merged.
- [ ] Login instructions, branch rules and "What Level 3 changes" are already
      in the README. Check they still match what you did.

### Step 23: Send to the team
- [ ] Message to the team chat, for example:

  > Level 1 is done. Repo: https://github.com/NSDVnsdv/SWE40006techtriage
  > Servers: dev http://..., test http://..., staging http://..., prod http://<elastic-ip>
  > Login is Session Manager only (no SSH), see the README. Branch rules: feature/* -> PR to develop
  > (1 approval + build check). Please accept the collaborator invite if you haven't.

### Step 24: Save money
- [ ] When nobody is using them: EC2 -> select development, testing, staging
      -> **Instance state** -> **Stop**. Leave production running during
      verification periods.
- Stopped servers get a **new public IP** when started again (production
  keeps its Elastic IP). On Learner Lab, instances may also be stopped when
  the lab session ends.

---

## Screenshot checklist

Save to a shared folder as `L1-<nn>-<name>.png`, and save the matching text
output as `.txt` next to it.

| # | Screenshot | Text to copy | Done |
|---|---|---|---|
| 01 | Repo home page | n/a | [ ] |
| 02 | Branch protection rules: `main` | n/a | [ ] |
| 03 | Branch protection rules: `develop` | n/a | [ ] |
| 04 | Secret scanning / push protection setting | n/a | [ ] |
| 05 | Test PR blocked until approval + check | rejected direct-push message | [ ] |
| 06 | Issue backlog | n/a | [ ] |
| 07 | Green Actions run (graph + Summary) | raw job log | [ ] |
| 08 | GHCR package page showing Public | anonymous `docker pull` output | [ ] |
| 09 | Budget alert (or Learner Lab spend display) | n/a | [ ] |
| 10 | IAM role / LabInstanceProfile permissions | policy name/JSON | [ ] |
| 11 | Security group inbound rules (HTTP 80 only) | n/a | [ ] |
| 12 | EC2 instance list with Name + Environment tags | n/a | [ ] |
| 13 | Fleet Manager: all 4 Online | n/a | [ ] |
| 14-17 | Session Manager terminal x4 (dev, test, staging, prod) | full terminal output x4 | [ ] |
| 18-21 | Placeholder page x4 in browser | `/version` output x4 | [ ] |
| 22 | SHA match: page vs Actions run vs `git rev-parse` | n/a | [ ] |

---

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `git push` rejected: "Updates were rejected... fetch first" | The repo was created with a README. Delete the repo and recreate it **empty**, or `git pull --rebase origin main` then push. |
| CI fails at the push step with `denied: permission_denied: write_package` | Package settings -> **Manage Actions access** -> add `SWE40006techtriage` with **Write**. Check Settings -> Actions -> General allows Actions to run. |
| `build` check doesn't appear in branch protection | It must have run at least once. Finish step 6 first, then search for `build`. |
| Server page doesn't load | (1) Use `http://`, not `https://`. (2) Security group has HTTP 80. (3) In Session Manager: `sudo tail -n 50 /var/log/techtriage-setup.log`. |
| Setup log shows `curl: (22) ... 404` on `compose.yaml` | `GITHUB_OWNER`/`GITHUB_REPO` is wrong, or the repo isn't public/pushed yet. The script stops there, so terminate the instance and relaunch it with corrected user data. |
| Setup log shows `unauthorized` / `denied` on `docker compose pull` | GHCR package is still private (step 7). Make it public, then `cd /opt/techtriage && docker compose up -d`. |
| `permission denied ... /var/run/docker.sock` | You forgot `sudo -i` in Session Manager. |
| Server missing from Fleet Manager | No instance profile attached, or no outbound internet. See step 18. |
| Page shows an old commit SHA | The server pulled `:latest` at boot. Run `docker compose pull && docker compose up -d`. |
