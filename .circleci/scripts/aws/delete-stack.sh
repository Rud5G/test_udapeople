#!/bin/bash

#set -x

#set -ue

delete_stack_name="${1:-}"

# shellcheck source=./aws-common-cli.sh
. "$(dirname "$0")/aws-common-cli.sh"

#aws_list_stacks
#aws_list_json_not_deleted_stacks | jq -r '{StackName}'


#aws_list_json_not_deleted_stacks | jq -r '.StackName'

#aws_list_json_not_deleted_stacks

if test -n "$DS_STACKNAME";
then
    aws_delete_stack "$DS_STACKNAME"
else
    aws_delete_stack "$delete_stack_name"
fi





