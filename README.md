# ec2remote

Save money running commands in AWS EC2 instances and stopping them on completion. From the command line.

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
- `-w <seconds>`: Wait x seconds before connecting. Default: `10`.

The instance will be started if needed before establishing the SSH connection.

After making sure that the instance is started and before trying to connect via SSH, the script will wait the number of seconds specified by the option `-w`. In some cases, trying to connect immediately after starting the instance will result in a failed connection error. The reason _could be_ that the SSH server takes a few seconds to initialize after boot. Usually, a wait of 10 seconds solves this problem.

If the `-d` option is present, the instance will be stopped when the SSH session finishes.

If the SSH session fails to start, for any reason, the instance will not be stopped (to allow faster retries) unless the `-f` option is present.

## Running a remote command in an instance

```bash
./ec2ssh.sh -i <instance id> <options> <command> [...<arguments>]
```

The options are the same than for the SSH interactive session plus:

- `-t <seconds>`: Establish a timeout for the remote command. Default: `0` (off).

Now, instead of opening an interactive session, the script will run a command and wait until its completion.

The session will be cut if `-t` is used and the remote command has not finished after the specified number of seconds.

After a timeout, the instance will be stopped only if both `-d` and `-f` options are present.

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
./ec2control.sh -i <instance id> -s
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

If the instance is starting, only if the argument `-f` (force) is present, it will wait until it is fully started and then it will bring it down again.

## Notes

This tool will not work with instances that are terminated or in the process of being terminated.

## Mnemotechnics for the options

- `i`: **I**nstance id
- `s`: **S**tart instance
- `d`: shut **D**own instance
- `f`: **F**orce shutdown
- `k`: ssh **K**ey file
- `p`: use **P**rivate ip address
- `u`: **U**sername
- `t`: **T**imeout seconds of remote command
- `w`: **W**ait seconds before connecting

## Example output

Command to list all files and shutdown:

```
./ec2ssh.sh -i i-01234567890123456 -d -f ls -laFh
```

Output:

```
===========================================================================
> Instance ID:   i-01234567890123456
> Key name:      my-ec2-instance
===========================================================================
Instance is stopped.
Starting up instance i-01234567890123456...
..............
> State:         16 (running)
> Public IP:     12.23.34.45
> Public host:   ec2-12-23-34-45.compute-1.amazonaws.com
> Private IP:    56.67.78.89
> Private host:  ip-56-67-78-89.ec2.internal

Waiting 10 seconds...

Connecting...
> IP address:    12.23.34.45
> User:          ubuntu
> PEM file:      ec2-i-01234567890123456-my-ec2-instance-us-east-1b.pem
> Command:       ls -laFh
> Timeout:       off

Warning: Permanently added '12.23.34.45' (ED34567) to the list of known hosts.
total 132K
drwxr-xr-x 14 ubuntu ubuntu 4.0K Jul  3 21:44 ./
drwxr-xr-x  3 root   root   4.0K Apr  1  2020 ../
-rw-------  1 ubuntu ubuntu  22K Jul  4 18:51 .bash_history
-rw-r--r--  1 ubuntu ubuntu  220 Apr  4  2018 .bash_logout
-rw-r--r--  1 ubuntu ubuntu 3.7K Apr  4  2018 .bashrc
[...more files...]

SSH session closed. Return code:  0
Shutting down.
===========================================================================
> Instance ID:   i-01234567890123456
> Key name:      my-ec2-instance
===========================================================================
Instance is running.
Shutting down instance i-01234567890123456...
..................
```
