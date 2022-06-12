# ec2remote

Save money running commands in EC2 instances and stopping them on completion.

As easy as:

```bash
./ec2ssh.sh -i <instance id> -d -f ls -laFh
```

## Installation

Clone this repo:

```bash
git clone https://github.com/jotaelesalinas/ec2remote.git
```

Install the dependencies:

- `aws-cli`: <https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html>
- `jq`: <https://stedolan.github.io/jq/download/>

Configure AWS-CLI:

```bash
aws configure
```

To configure AWS CLI you will need:

- The region of your instance.
- From IAM, an access key and secret key: <https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html>

Now, inside EC2, create an access key and download the PEM file: <https://console.aws.amazon.com/ec2/v2/home#KeyPairs:>

Save the PEM file in the `ec2remote` folder. Don't change the name.

## Interactive SSH session into an instance

```bash
./ec2ssh.sh -i <instance id> <options>
```

Options: `[-k <pem file>] [-u <username>] [-d [-f]] [-p]`

Where:
- `-i <instance id>`: Your EC2 instance ID. Not the image ID.
- `-k <pem file>`: The keypair file. Default: the script will search for a file named `ec2-<instance id>*.pem` in the working directory.
- `-u <username>`: Username of remote host. Default: `ubuntu`.
- `-d`: Shut down instance after the session is closed.
- `-f`: Force shutdown even if the SSH connection fails. Only used with `-d`.
- `-p`: Use the private IP address instead of the public.

The instance will be started if needed before establishing the SSH connection.

If the `-d` option is present, the instance will be stopped when the SSH session finishes.

If the SSH session fails to start, for any reason, the instance will not be stopped (to allow faster retries) unless the `-f` option is present.

## Running a remote command in an instance

```bash
./ec2ssh.sh -i <instance id> <options> <command> [...<arguments>]
```

The options are the same than for the SSH interactive session.

Now, instead of opening an interactive session, the script will run a command and wait until its completion.

Important! If the remote command gets stuck for any reason, the session will remain open. It is recommended to wrap `ec2ssh.sh` with a command like `timeout` to establish a time limit and avoid surprises in the invoice.

## Show the status of an instance

```bash
./ec2control.sh -i <instance id>
```

This command will show just the bare minimum information needed to run remote commands in your EC2 instance. If you want to retrieve the complete information, run:

```bash
aws ec2 describe-instances --instance-id <instance id> | jq
```

## Starting an instance

```bash
./ec2control.sh -i <instance id> -u
```

The instance will be started, unless it is already started.

If the instance is starting, it will just wait until it is fully started.

If the instance is stopping, it will wait until it is fully stopped and
then it will bring it up.

## Stopping an instance

```bash
./ec2control.sh -i <instance id> -d [-f]
```

The instance will be stopped, unless it is already stopped.

If the instance is stopping, it will just wait until it is fully stopped.

If the instance is starting, only if the argument -f (force) is present, it will wait until it is fully started and then it will bring it down again.

## Notes

This tool will not work with instances that are terminated or in the process of being terminated.
