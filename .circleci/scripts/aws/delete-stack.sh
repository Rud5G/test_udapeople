#!/bin/bash

#set -x

set -ue

delete_stack_name="$1"

# shellcheck source=./aws-common-cli.sh
. "$(dirname "$0")/aws-common-cli.sh"

#aws_list_stacks
#aws_list_json_not_deleted_stacks | jq -r '{StackName}'


#aws_list_json_not_deleted_stacks | jq -r '.StackName'

#aws_list_json_not_deleted_stacks

aws_delete_stack "$delete_stack_name"
