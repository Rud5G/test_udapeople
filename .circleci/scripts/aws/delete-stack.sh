#!/bin/bash

set -ue

STACK_NAME="$1"

# shellcheck source=./aws-common-cli.sh
. "$(dirname "$0")/aws-common-cli.sh"

aws_delete_stack "$STACK_NAME"



