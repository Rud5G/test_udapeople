#!/bin/bash

#set -x

# shellcheck source=./aws-common-cli.sh
. "$(dirname "$0")/aws-common-cli.sh"

#aws_list_stacks
#aws_list_json_not_deleted_stacks | jq -r '{StackName}'


#aws_list_json_not_deleted_stacks | jq -r '.StackName'

#aws_list_json_not_deleted_stacks

aws_delete_stack "udapeople-frontend-3d3f6b6"

#aws_delete_stack "udapeople-backend-3d3f6b6"
