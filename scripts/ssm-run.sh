#!/usr/bin/env bash
# Below is the code to run a script on one server through AWS Systems Manager (no SSH needed), wait for it
# to finish, and print everything the server printed. It fails if the script failed on the server.
# Usage: bash scripts/ssm-run.sh <instance-id> "<short comment>" <script-file>
set -euo pipefail
instance="$1"
comment="$2"
file="$3"

# Below is the code to send the script's lines to the server as one Systems Manager "Run Shell Script" command.
params=$(jq -Rs '{commands: split("\n")}' "$file")
id=$(aws ssm send-command --instance-ids "$instance" --document-name AWS-RunShellScript \
  --comment "${comment:0:100}" --parameters "$params" --query Command.CommandId --output text)
echo "Systems Manager command ID: $id"

# Below is the code to check every 5 seconds, for up to 5 minutes, until the command has finished.
status=Pending
for _ in $(seq 1 60); do
  sleep 5
  status=$(aws ssm get-command-invocation --command-id "$id" --instance-id "$instance" \
    --query Status --output text 2>/dev/null || echo Pending)
  case "$status" in Pending|InProgress|Delayed) continue ;; *) break ;; esac
done

# Below is the code to print the server's output and fail unless Systems Manager reports "Success".
echo "----- output from the server -----"
aws ssm get-command-invocation --command-id "$id" --instance-id "$instance" \
  --query '[StandardOutputContent, StandardErrorContent]' --output text
echo "----- Systems Manager status: $status -----"
[ "$status" = Success ]
