#!/bin/bash
set -u

EC2CONTROL=./ec2control.sh

DEFAULT_USERNAME="ubuntu"

INSTANCE_ID=
USERNAME=$DEFAULT_USERNAME
PEM_FILE=
USE_PRIVATE_IP=0
SHUTDOWN=0
FORCE_SHUTDOWN=0
TIMEOUT=0

function error () {
    echo "" >&2
    echo "Error: $1" >&2
    exit $2
}

# do not modify!
# https://www.cyberciti.biz/faq/what-are-the-exit-statuses-of-ssh-command/
SSH_CONN_REFUSED=255
SSH_CONN_TIMEDOUT=124

############################################################################
# usage and read arguments
############################################################################

function usage () {
    __USAGE="Usage: -i <instance id> [options] [<remote command>]

Where:
    -i <instance id>: The instance ID of your EC2 instance --not image.

Options:
    -k <pem file>: Location of the PEM file with the SSH key. Default:
        ec2-<instance id>*.pem in the working directory.
    -u <username>: Username of remote host. Default: $DEFAULT_USERNAME.
    -t <seconds>: Establishes a timeout for the remote command. Default: off.
    -d: Shut down instance after the session is closed.
    -f: Force shutdown even if the SSH connection fails.
    -p: Switch to use private IP address instead of public.

<remote command> is anything you want to run on the remote server.
    Optional. If missing, you will start an interactive session with
    the default shell.
"

    if [[ $# -gt 0 ]]; then
        echo "Error: $1" >&2
        echo "" >&2
    fi
    echo "$__USAGE" >&2

    which $EC2CONTROL > /dev/null 2> /dev/null
    if [ $? -ne 0 ]; then
        echo "Warning! Dependency $EC2CONTROL not found."
    else
        echo "Dependency $EC2CONTROL found."
    fi

    which aws > /dev/null 2> /dev/null
    if [ $? -ne 0 ]; then
        echo "Warning! Dependency aws not found."
    else
        echo "Dependency aws found."
    fi

    which jq > /dev/null 2> /dev/null
    if [ $? -ne 0 ]; then
        echo "Warning! Dependency jq not found."
    else
        echo "Dependency jq found."
    fi

    exit 1;
}

while getopts ":i:k:u:t:dfp" VARNAME; do
    case $VARNAME in
        i)
            INSTANCE_ID="$OPTARG"
            ;;
        k)
            PEM_FILE="$OPTARG"
            ;;
        u)
            USERNAME="$OPTARG"
            ;;
        t)
            TIMEOUT=$((OPTARG+0))
            ;;
        d)
            SHUTDOWN=1
            ;;
        f)
            FORCE_SHUTDOWN=1
            ;;
        p)
            USE_PRIVATE_IP=1
            ;;
        \?)
            usage "Invalid option -$OPTARG"
            ;;
        :)
            usage "Option -$VARNAME requires a parameter."
            ;;
    esac
done

# remove all options from the argument list
shift $((OPTIND - 1))

############################################################################
# 1. some checks
############################################################################

if [ -z $INSTANCE_ID ]; then
    usage "Missing instance id" 1
fi

############################################################################
# 2. get pem file
############################################################################

if [ -z $PEM_FILE ]; then
    NUM_PEM_FILES=`ls ec2-$INSTANCE_ID*.pem | wc -l`
    if [ $NUM_PEM_FILES -eq 0 ]; then
        error "No PEM file found matching ec2-$INSTANCE_ID*.pem" 2
    elif [ $NUM_PEM_FILES -gt 1 ]; then
        error "More than one PEM file found matching ec2-$INSTANCE_ID*.pem" 2
    fi
    PEM_FILE=`ls ec2-$INSTANCE_ID*.pem | head -n 1`
fi

if [ ! -f $PEM_FILE ]; then
    usage "PEM file $PEM_FILE does not exist." 3
fi

############################################################################
# 3. get ip address
############################################################################

$EC2CONTROL -i $INSTANCE_ID -u
RETCODE=$?

if [ $RETCODE -ne 0 ]; then
    exit $RETCODE
fi

if [ $USE_PRIVATE_IP -eq 1 ]; then
    IP_LINE=`$EC2CONTROL -i $INSTANCE_ID | grep "Private IP"`
else
    IP_LINE=`$EC2CONTROL -i $INSTANCE_ID | grep "Public IP"`
fi

ARR=($IP_LINE)
IP_ADDRESS=${ARR[3]}

############################################################################
# 4. connect
############################################################################

echo ""
echo "Connecting..."
echo "- IP address:    $IP_ADDRESS"
echo "- User:          $USERNAME"
echo "- PEM file:      $PEM_FILE"
if [ $# -gt 0 ]; then
    echo "- Command:       $*"
    if [ $TIMEOUT -gt 0 ]; then
        echo "- Timeout:       $TIMEOUT s"
    else
        echo "- Timeout:       off"
    fi
fi
echo ""

if [ $# -gt 0 ] && [ $TIMEOUT -gt 0 ]; then
    timeout --kill-after=3 $TIMEOUT \
        ssh -i $PEM_FILE -o StrictHostKeyChecking=no $USERNAME@$IP_ADDRESS $*
else
    ssh -i $PEM_FILE -o StrictHostKeyChecking=no $USERNAME@$IP_ADDRESS $*
fi

RETCODE=$?
if [ $RETCODE -eq $SSH_CONN_REFUSED ]; then
    if [ $SHUTDOWN -eq 1 ] && [ $FORCE_SHUTDOWN -eq 1 ]; then
        echo "Forcing shutdown."
        $EC2CONTROL -i $INSTANCE_ID -d
    fi
    error "SSH connection failed ($RETCODE)." $RETCODE
elif [ $RETCODE -eq $SSH_CONN_TIMEDOUT ]; then
    if [ $SHUTDOWN -eq 1 ] && [ $FORCE_SHUTDOWN -eq 1 ]; then
        echo "Forcing shutdown."
        $EC2CONTROL -i $INSTANCE_ID -d
    fi
    error "Remote command timed out ($RETCODE)." $RETCODE
fi

echo ""
echo "SSH session closed. Return code: " $RETCODE

if [ $SHUTDOWN -eq 1 ]; then
    echo "Shutting down."
    $EC2CONTROL -i $INSTANCE_ID -d
fi
