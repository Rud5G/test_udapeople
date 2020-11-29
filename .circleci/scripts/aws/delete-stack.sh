#!/bin/bash

set -x

# shellcheck source=./aws-common-cli.sh
. "$(dirname "$0")/aws-common-cli.sh"

aws_list_stacks



