resource "terraform_data" "github_runner" {
  count = var.github_runner_enabled ? 1 : 0

  triggers_replace = [
    aws_instance.acumen_node["node1"].id,
    var.github_repository,
    var.github_runner_name
  ]

  provisioner "local-exec" {
    environment = {
      GITHUB_RUNNER_TOKEN = var.github_runner_token
      GITHUB_REPOSITORY   = var.github_repository
      GITHUB_RUNNER_NAME  = var.github_runner_name
      TARGET_INSTANCE_ID  = aws_instance.acumen_node["node1"].id
      AWS_REGION          = var.aws_region
    }

    command = <<SCRIPT
set -euo pipefail

if [ -z "$${GITHUB_RUNNER_TOKEN}" ]; then
  echo "ERROR: GITHUB_RUNNER_TOKEN is empty."
  exit 1
fi

if [ -z "$${GITHUB_REPOSITORY}" ]; then
  echo "ERROR: GITHUB_REPOSITORY is empty."
  exit 1
fi

echo "Sending GitHub Actions runner bootstrap to acumen-node-1..."

RUNNER_SCRIPT="$(sed \
  -e "s|__GITHUB_REPOSITORY__|$${GITHUB_REPOSITORY}|g" \
  -e "s|__GITHUB_RUNNER_TOKEN__|$${GITHUB_RUNNER_TOKEN}|g" \
  -e "s|__GITHUB_RUNNER_NAME__|$${GITHUB_RUNNER_NAME}|g" \
  templates/runner.sh)"

PARAMETERS_JSON="$(jq -n \
  --arg script "$${RUNNER_SCRIPT}" \
  '{commands: [$script]}')"

COMMAND_ID="$(aws ssm send-command \
  --region "$${AWS_REGION}" \
  --instance-ids "$${TARGET_INSTANCE_ID}" \
  --document-name "AWS-RunShellScript" \
  --parameters "$${PARAMETERS_JSON}" \
  --query "Command.CommandId" \
  --output text)"

echo "SSM command submitted: $${COMMAND_ID}"

echo "Waiting for runner bootstrap..."

for i in $(seq 1 60); do
  STATUS="$(aws ssm get-command-invocation \
    --region "$${AWS_REGION}" \
    --command-id "$${COMMAND_ID}" \
    --instance-id "$${TARGET_INSTANCE_ID}" \
    --query "Status" \
    --output text 2>/dev/null || true)"

  case "$${STATUS}" in
    Success)
      echo "GitHub Actions runner bootstrap completed successfully."

      aws ssm get-command-invocation \
        --region "$${AWS_REGION}" \
        --command-id "$${COMMAND_ID}" \
        --instance-id "$${TARGET_INSTANCE_ID}" \
        --query "StandardOutputContent" \
        --output text

      exit 0
      ;;

    Failed|Cancelled|TimedOut|Cancelling)
      echo "GitHub Actions runner bootstrap failed: $${STATUS}"

      aws ssm get-command-invocation \
        --region "$${AWS_REGION}" \
        --command-id "$${COMMAND_ID}" \
        --instance-id "$${TARGET_INSTANCE_ID}" \
        --query "StandardErrorContent" \
        --output text

      exit 1
      ;;

    *)
      echo "Current SSM status: $${STATUS:-Pending}"
      sleep 10
      ;;
  esac
done

echo "ERROR: Timed out waiting for SSM command."
exit 1
SCRIPT
  }
}
