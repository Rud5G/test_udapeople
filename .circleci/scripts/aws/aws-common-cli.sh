#!/bin/bash

#set -e
#set -x

AWS_CLI_VERSION=2
DEBUG=true

# Usage: msg <message>
#
#   Writes <message> to STDERR only if $DEBUG is true, otherwise has no effect.
msg() {
    local message="$1"
    $DEBUG && echo "$message" 1>&2
    return 0
}

# Usage: error_exit <message>
#
#   Writes <message> to STDERR as a "fatal" and immediately exits the currently running script.
error_exit() {
    local message=$1
    echo "[FATAL] $message" 1>&2
    exit 1
}

# Usage: env_has_dependency <command>
#
#   Returns 0 on success (has dependency) or non-zero if it fails (does not have the dependency)
env_has_dependency() {
    local dependency=$1
    if ! command -v "$dependency" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# Usage: get_aws_installed_major_version
#
#   Writes currently installed aws-cli version to STDOUT
#   If no version is installed or recongnized, version is "0"
aws_cli_installed_version() {
    local AWS_VER_REGEXP_X='aws-cli\/\d*.\d*.\d*'
    local AWS_CLI_INSTALLED_VERSION="0"
    local CURRENT_AWS_VERSION

    if ! env_has_dependency "aws"; then
        echo "$AWS_CLI_INSTALLED_VERSION"
        return 0
    fi

    CURRENT_AWS_VERSION="$(aws --version 2>&1)"
    if aws --version 2>&1 | grep -q $AWS_VER_REGEXP_X; then
        AWS_CLI_INSTALLED_VERSION="${CURRENT_AWS_VERSION:8:1}"
    else
        msg "unknown version installed"
    fi

    echo "$AWS_CLI_INSTALLED_VERSION"
}

# Usage: get_platform_env
#
#   Writes <linux|darwin> to STDOUT when recognized either platform or immediately exits the currently running script.
get_platform_env() {
    local SYS_ENV_PLATFORM
    local SYS_INFO

    set +ex

    SYS_INFO="$(uname -o)"

    # PLATFORM CHECK: mac vs. alpine vs. other linux
    if test -n "$(echo "$SYS_INFO" | grep "Darwin")"; then
        SYS_ENV_PLATFORM="darwin"
    elif test -n "$(echo "$SYS_INFO" | grep "Linux")"; then
        SYS_ENV_PLATFORM="linux"
    else
        error_exit "This platform appears to be unsupported: $SYS_INFO"
    fi

    echo "$SYS_ENV_PLATFORM"
}

# Usage: aws_check_dependencies
aws_check_dependencies() {
    if ! env_has_dependency "jq"; then
        msg "Your environment does not seem to have jq installed, a requirement."
        error_exit "Please utilize an envionment with jq installed."
    fi

    if ! env_has_dependency "python3" && ! env_has_dependency "python"; then
        msg "Your environment does not seem to have Python installed, a requirement of the AWS CLI."
        error_exit "Please utilize an envionment with Python installed."
    fi

    if ! env_has_dependency "unzip"; then
        msg "Your environment does not seem to have UnZip installed, a requirement of the AWS CLI."
        error_exit "Please utilize an envionment with UnZip installed."
    fi
}

# Usage: get_sudo
get_sudo() {
    if test $EUID -eq 0; then
        echo ""
    else
        if ! env_has_dependency "sudo"; then
            error_exit "\$EUID = $EUID, but sudo is not available. Please utilize an envionment with sudo installed."
        fi

        if test "$(is_interactive)" != "0"; then
            if ! sudo -n true 2>/dev/null; then
                error_exit "this is a non-interactive script, and does not run as (passordless) root."
            fi
        fi

        echo "sudo"
    fi
}

# Usage: is_interactive
#
#   Writes 0 to STDOUT when i - interactive is current shell options,
is_interactive() {
    set -x
    # shellcheck disable=SC2005
    echo $-
    case $- in
    *i*)
        echo "0"
        ;;
    *)
        echo $SHLVL
        exit
        echo "1"
        ;;
    esac
}

# Usage: do_sleep_check <nr_of_seconds>
do_sleep_check() {
    local seconds=$1
    msg "sleep $seconds seconds"
    sleep "$seconds"
}

#install_aws_v1() {
#    error_exit "install aws-cli v1 is not implemented."
#}

# Usage: install_aws_v2
install_aws_v2() {
    local SYS_ENV_PLATFORM
    local SUDO
    local UPGRADE_ARG=""
    local TEMPDIR

    SYS_ENV_PLATFORM="$(get_platform_env)"
    SUDO="$(get_sudo)"

    if env_has_dependency "aws"; then
        UPGRADE_ARG="--update"
    fi

    set -ex

    TEMPDIR=$(mktemp -d) || error_exit "mktemp is not available."

    case "$SYS_ENV_PLATFORM" in
    linux)
        pushd "$TEMPDIR"
        curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TEMPDIR/awscliv2.zip"
        unzip -q "$TEMPDIR/awscliv2.zip"
        $SUDO ./aws/install $UPGRADE_ARG
        rm awscliv2.zip
        popd
        ;;
    darwin)
        curl -sSL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
        $SUDO installer -pkg AWSCLIV2.pkg -target /
        rm AWSCLIV2.pkg
        ;;
    *)
        error_exit "This platform appears to be unsupported. '$SYS_ENV_PLATFORM'"
        ;;
    esac
}

install_aws() {
    local CURRENT_AWS_VERSION
    CURRENT_AWS_VERSION=$(aws_cli_installed_version)

    aws_check_dependencies

    if test "$CURRENT_AWS_VERSION" -ne "$AWS_CLI_VERSION"; then
        if ! env_has_dependency "aws"; then
            msg "AWS is not installed"
        else
            msg "current installed install AWS version $CURRENT_AWS_VERSION"
        fi

        msg "installing aws-cli version: $AWS_CLI_VERSION"

        do_sleep_check 1

        install_aws_v2
    else
        msg "aws-cli/v2 installed."
    fi
}

# Usage: get_all_tags <resource_id>
#
#   Writes to STDOUT all the tags for the resource_id.
get_all_tags() {
    local resource_id=$1
    local instance_tags

    if test -z "${INSTANCE_TAGS:-}"; then
        instance_tags=$(aws ec2 describe-tags \
            --filters "Name=resource-id,Values=${resource_id}" \
            --query 'Tags[].[Key,Value]' --output text)
        INSTANCE_TAGS="${instance_tags,,}"
    fi

    echo "$INSTANCE_TAGS"
}

#  CREATE_IN_PROGRESS
#  CREATE_FAILED
#  CREATE_COMPLETE
#  ROLLBACK_IN_PROGRESS
#  ROLLBACK_FAILED
#  ROLLBACK_COMPLETE
#  DELETE_IN_PROGRESS
#  DELETE_FAILED
#  DELETE_COMPLETE
#  UPDATE_IN_PROGRESS
#  UPDATE_COMPLETE_CLEANUP_IN_PROGRESS
#  UPDATE_COMPLETE
#  UPDATE_ROLLBACK_IN_PROGRESS
#  UPDATE_ROLLBACK_FAILED
#  UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS
#  UPDATE_ROLLBACK_COMPLETE
#  REVIEW_IN_PROGRESS
#  IMPORT_IN_PROGRESS
#  IMPORT_COMPLETE
#  IMPORT_ROLLBACK_IN_PROGRESS
#  IMPORT_ROLLBACK_FAILED
#  IMPORT_ROLLBACK_COMPLETE

aws_disable_pager() {
    export AWS_PAGER=""
}

# Usage: aws_list_stacks <message>
#
#   Writes <message> to STDERR only if $DEBUG is true, otherwise has no effect.
aws_list_stacks() {
    #    local statuses=
    aws cloudformation list-stacks
    #    --stack-status-filter
}

aws_describe_stack() {
    local stackname=$1
    aws cloudformation describe-stacks --stack-name "$stackname"
}

#    {
#      "StackId": "arn:aws:cloudformation:us-west-2:877977268182:stack/udapeople-frontend-3d3f6b6/6790beb0-326f-11eb-9d22-02006f42ed61",
#      "StackName": "udapeople-frontend-3d3f6b6",
#      "TemplateDescription": "UdaPeople frontend stack.\n",
#      "CreationTime": "2020-11-29T18:19:22.637000+00:00",
#      "LastUpdatedTime": "2020-11-29T18:19:28.141000+00:00",
#      "StackStatus": "CREATE_COMPLETE",
#      "DriftInformation": {
#        "StackDriftStatus": "NOT_CHECKED"
#      }
#    }

aws_list_json_not_deleted_stacks() {
    local stacklist
    # aws cloudformation list-stacks | jq -r '.StackSummaries[] | select([.StackStatus] | inside(["DELETE_COMPLETE", "DELETE_IN_PROGRESS"]) | not) | {StackName, StackId}'
    aws_disable_pager
    stacklist=$(aws cloudformation list-stacks | jq -r '.StackSummaries[] | select([.StackStatus] | inside(["DELETE_COMPLETE", "DELETE_IN_PROGRESS"]) | not)')
    echo "$stacklist"
}

aws_list_json_stack_resources() {
    local stackname=$1
    local filter_resourcetype="${2:-}"
    local stackresources

    stackresources=$(aws cloudformation list-stack-resources \
        --stack-name "$stackname" | jq -r '.StackResourceSummaries[]')

    if test -n "$filter_resourcetype"; then
        stackresources=$(jq -r '. | select(.ResourceType == "'"$filter_resourcetype"'")' <<<"$stackresources")
    fi

    echo "$stackresources"
}

aws_stack_has_s3_bucket() {
    local stackname=$1
    local resource_type_s3_bucket="AWS::S3::Bucket"
    local bucketname

    bucketname=$(aws_list_json_stack_resources "$stackname" "$resource_type_s3_bucket")
    echo "$bucketname"
}

# grep -q 'hello' <<< 'hello world'
# jq '.[] | select(.location=="Stockholm")' json

aws_delete_stack() {
    local stackname=$1
    local not_deleted_stacknames
    local bucketname

    not_deleted_stacknames=$(aws_list_json_not_deleted_stacks | jq -r '.StackName')

    if ! grep -q "$stackname" <<<"$not_deleted_stacknames"; then
        error_exit "$stackname is not found in list deleteable stacknames"
    fi

    bucketname=$(aws_stack_has_s3_bucket "$stackname" | jq -r '.PhysicalResourceId')
    if test -n "$bucketname";
    then
        aws s3 rm "s3://$bucketname" --recursive
    fi

    aws cloudformation delete-stack \
        --stack-name "$stackname"
}




# Install AWS-cli v2.
install_aws
