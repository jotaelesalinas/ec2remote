#!/bin/bash
set -u

# do not modify
# https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-instance-status.html
STATUS_CODE_TERMINATED=48
STATUS_CODE_SHUTTING_DOWN=32
STATUS_CODE_STOPPING=64
STATUS_CODE_STOPPED=80
STATUS_CODE_PENDING=0
STATUS_CODE_RUNNING=16

function usage () {
    __USAGE="Usage: $(basename $0) -i <instance id> [ -s | -d [-f] ]

Options:
    -i <instance id>: Id of the EC2 instance
    -s: Starts the instance
    -d: Shuts down the instance
    -f: Forces shutdown when instance is starting
"

    if [[ $# -gt 0 ]]; then
        echo "Error: $1" >&2
        echo "" >&2
    fi
    echo "$__USAGE" >&2

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

function error () {
    echo "" >&2
    echo "Error: $1" >&2
    exit $2
}



function check_deps () {
    which aws > /dev/null 2> /dev/null
    if [ $? -ne 0 ]; then
        error "Missing dependency aws" 2
    fi

    which jq > /dev/null 2> /dev/null
    if [ $? -ne 0 ]; then
        error "Missing dependency jq" 2
    fi
}

function remove_quotes () {
    echo $1 | sed -e 's/^"//' -e 's/"$//'
}

function status_code () {
    # $1 is the instance id

    if [ -z $1 ]; then
        error "Missing instance id in status() function" 3
    fi

    STATUS_JSON=`aws ec2 describe-instances --instance-id $1`
    if [ $? -ne 0 ]; then
        error "Could not retrieve instance status" 3
    fi

    STATUS_STATE_CODE=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].State.Code'`
    
    return $STATUS_STATE_CODE
}

FIRST_STATUS_RUN=1

function show_status () {
    # $1 is the instance id

    if [ -z $1 ]; then
        error "Missing instance id in status() function" 3
    fi

    STATUS_JSON=`aws ec2 describe-instances --instance-id $1`
    if [ $? -ne 0 ]; then
        error "Could not retrieve instance status" 3
    fi

    STATUS_STATE_CODE=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].State.Code'`
    
    STATUS_STATE_NAME=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].State.Name'`
    STATUS_STATE_NAME=`remove_quotes $STATUS_STATE_NAME`
    
    STATUS_PUBLIC_IP=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].PublicIpAddress'`
    STATUS_PUBLIC_IP=`remove_quotes $STATUS_PUBLIC_IP`
    if [ $STATUS_PUBLIC_IP == "null" ]; then
        STATUS_PUBLIC_IP=""
    fi

    STATUS_PUBLIC_HOSTNAME=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].PublicDnsName'`
    STATUS_PUBLIC_HOSTNAME=`remove_quotes $STATUS_PUBLIC_HOSTNAME`
    
    STATUS_PRIVATE_IP=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].PrivateIpAddress'`
    STATUS_PRIVATE_IP=`remove_quotes $STATUS_PRIVATE_IP`
    
    STATUS_PRIVATE_HOSTNAME=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].PrivateDnsName'`
    STATUS_PRIVATE_HOSTNAME=`remove_quotes $STATUS_PRIVATE_HOSTNAME`

    INSTANCE_KEY_NAME=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].KeyName'`
    INSTANCE_KEY_NAME=`remove_quotes $INSTANCE_KEY_NAME`
    INSTANCE_TYPE=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].InstanceType'`
    INSTANCE_TYPE=`remove_quotes $INSTANCE_TYPE`

    INSTANCE_ZONE=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].Placement.AvailabilityZone'`
    INSTANCE_ZONE=`remove_quotes $INSTANCE_ZONE`

    ARCHITECTURE=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].Architecture'`
    ARCHITECTURE=`remove_quotes $ARCHITECTURE`
    CORES=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].CpuOptions.CoreCount'`
    CORES=`remove_quotes $CORES`
    THREADS=`echo $STATUS_JSON | jq '.Reservations[0].Instances[0].CpuOptions.ThreadsPerCore'`
    THREADS=`remove_quotes $THREADS`

    if [ $FIRST_STATUS_RUN -eq 1 ]; then
        echo "==========================================================================="
        echo "> Instance ID:   $INSTANCE_ID"
        echo "> Key name:      $INSTANCE_KEY_NAME"
        #echo "> Avail. zone:   $INSTANCE_ZONE"
        #echo "> Instance type: $INSTANCE_TYPE"
        #echo "> Architecture:  $ARCHITECTURE"
        #echo "> Cores:         $CORES"
        #echo "> Threads/core:  $THREADS"
        echo "==========================================================================="
    else
        echo "> State:         $STATUS_STATE_CODE ($STATUS_STATE_NAME)"
        echo "> Public IP:     $STATUS_PUBLIC_IP"
        echo "> Public host:   $STATUS_PUBLIC_HOSTNAME"
        echo "> Private IP:    $STATUS_PRIVATE_IP"
        echo "> Private host:  $STATUS_PRIVATE_HOSTNAME"
    fi


    FIRST_STATUS_RUN=0
    return $STATUS_STATE_CODE
}

function up () {
    # $1 is the instance id
    echo "Starting up instance $1..."
    aws ec2 start-instances --instance-ids $1 > /dev/null
}

function down () {
    # $1 is the instance id
    echo "Shutting down instance $1..."
    aws ec2 stop-instances --instance-ids $1 > /dev/null
}

function wait_status () {
    # $1 is the instance id
    # $2 is the expected status code
    
    status_code $1
    STATUS=$?

    while [ ! $STATUS -eq $2 ]; do
        printf "."
        status_code $1
        STATUS=$?
    done

    printf "\n"
}

NUM_OPTS=0
INSTANCE_ID=
ACTION=status
ACTION_UP=0
ACTION_DOWN=0
FORCE_SHUTDOWN=0
SHOW_PUBLIC_IP=0

while getopts ":i:sdf" VARNAME; do
    case $VARNAME in
        i)
            INSTANCE_ID="$OPTARG"
            ((NUM_OPTS=NUM_OPTS+1))
            ;;
        s)
            ACTION_UP=1
            ((NUM_OPTS=NUM_OPTS+1))
            ;;
        d)
            ACTION_DOWN=1
            ((NUM_OPTS=NUM_OPTS+1))
            ;;
        f)
            FORCE_SHUTDOWN=1
            ((NUM_OPTS=NUM_OPTS+1))
            ;;
        \?)
            usage "Invalid option -$OPTARG"
            ;;
        :)
            usage "Option -$OPTARG requires a parameter."
            ;;
    esac
done

REGEX_INSTANCE_ID="^i-[a-z0-9]+$"

if [ $NUM_OPTS -eq 0 ]; then
    usage
    exit 1
elif [ $INSTANCE_ID == "" ]; then
    usage
    exit 1
elif ! [[ $INSTANCE_ID =~ $REGEX_INSTANCE_ID ]]; then
    error "Wrong instance id format." 1
elif [ $ACTION_UP -eq 1 ] && [ $ACTION_DOWN -eq 1 ]; then
    error "Cannot turn the instance up and down at the same time." 1
elif [ $ACTION_UP -eq 1 ]; then
    ACTION=up
elif [ $ACTION_DOWN -eq 1 ]; then
    ACTION=down
fi

check_deps

show_status $INSTANCE_ID
STATUS=$?

if [ $ACTION == "down" ]; then
    if [ $STATUS -eq $STATUS_CODE_STOPPED ]; then
        echo "Instance already shut down."
    elif [ $STATUS -eq $STATUS_CODE_TERMINATED ]; then
        echo "Instance is terminated."
    elif [ $STATUS -eq $STATUS_CODE_SHUTTING_DOWN ]; then
        echo "Instance is terminating..."
        wait_status $INSTANCE_ID $STATUS_CODE_TERMINATED
    elif [ $STATUS -eq $STATUS_CODE_STOPPING ]; then
        echo "Instance is shutting down..."
        wait_status $INSTANCE_ID $STATUS_CODE_STOPPED
    elif [ $STATUS -eq $STATUS_CODE_RUNNING ]; then
        echo "Instance is running."
        down $INSTANCE_ID
        wait_status $INSTANCE_ID $STATUS_CODE_STOPPED
    elif [ $STATUS -eq $STATUS_CODE_PENDING ]; then
        if [ $FORCE_SHUTDOWN -eq 0 ]; then
            echo "Instance is starting up. Use -f to force shutdown."
        else
            echo "Instance is starting up. Forcing shutdown."
            echo "Waiting for instance to finish start..."
            wait_status $INSTANCE_ID $STATUS_CODE_RUNNING
            echo "Now it's running."
            down $INSTANCE_ID
            wait_status $INSTANCE_ID $STATUS_CODE_STOPPED
        fi
    else
        error "Unknown status code $STATUS." 4
    fi
elif [ $ACTION == "up" ]; then
    if [ $STATUS -eq $STATUS_CODE_RUNNING ]; then
        echo "Instance already running."
    elif [ $STATUS -eq $STATUS_CODE_PENDING ]; then
        echo "Instance is starting up..."
        wait_status $INSTANCE_ID $STATUS_CODE_RUNNING
    elif [ $STATUS -eq $STATUS_CODE_TERMINATED ]; then
        error "Instance is terminated." 5
    elif [ $STATUS -eq $STATUS_CODE_SHUTTING_DOWN ]; then
        error "Instance is terminating." 5
    elif [ $STATUS -eq $STATUS_CODE_STOPPED ]; then
        echo "Instance is stopped."
        up $INSTANCE_ID
        wait_status $INSTANCE_ID $STATUS_CODE_RUNNING
    elif [ $STATUS -eq $STATUS_CODE_STOPPING ]; then
        echo "Instance is shutting down. Forcing startup."
        echo "Waiting for instance to finish stop..."
        wait_status $INSTANCE_ID $STATUS_CODE_STOPPED
        echo "Now it's stopped."
        up $INSTANCE_ID
        wait_status $INSTANCE_ID $STATUS_CODE_RUNNING
    else
        error "Unknown status code $STATUS." 4
    fi
    show_status $INSTANCE_ID
elif [ $ACTION == "status" ]; then
    show_status $INSTANCE_ID
else
    error "Unknown action $ACTION." 4
fi

exit 0
