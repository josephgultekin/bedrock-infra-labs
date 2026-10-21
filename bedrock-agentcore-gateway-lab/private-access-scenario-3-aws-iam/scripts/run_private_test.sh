#!/bin/bash
# Runs the Gateway test ON the bastion via SSM (not locally - the whole
# point of this scenario is that the Gateway call can only succeed from
# inside the VPC). This script itself just calls the public SSM API from
# your laptop; the actual SigV4-signed Gateway call happens device-side on
# the bastion, using its own scoped IAM role.
#
# Setup:
#   export AWS_PROFILE=dops
#   export BASTION_INSTANCE_ID=$(tofu -chdir=.. output -raw bastion_instance_id)
#
# Run:
#   ./run_private_test.sh
set -euo pipefail

: "${BASTION_INSTANCE_ID:?Set BASTION_INSTANCE_ID first - see this script's Setup comment}"
REGION="${AWS_REGION:-us-east-1}"

echo "Dispatching via SSM to $BASTION_INSTANCE_ID..."
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$BASTION_INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["python3 /opt/gateway_test.py"]' \
  --region "$REGION" \
  --query "Command.CommandId" \
  --output text)

echo "Command ID: $COMMAND_ID - waiting for it to finish..."
aws ssm wait command-executed \
  --command-id "$COMMAND_ID" \
  --instance-id "$BASTION_INSTANCE_ID" \
  --region "$REGION" || true  # wait exits non-zero on a Failed status too - still want to print output below

aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$BASTION_INSTANCE_ID" \
  --region "$REGION" \
  --query "{Status:Status,StdOut:StandardOutputContent,StdErr:StandardErrorContent}" \
  --output json
