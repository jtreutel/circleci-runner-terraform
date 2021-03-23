#!/bin/bash

# Based on circleci-docs 6fca959612290e1bf880200e46e3225542fcb126

#Prerequisites:
# Complete these:
#  https://circleci.com/docs/2.0/runner-installation/#authentication


platform="linux/amd64"                                  #Runner platform: linux/amd64 || linux/arm64 || platform=darwin/amd64 
prefix="/opt/circleci"                                  #Runner install directory    

CONFIG_PATH="/opt/circleci/launch-agent-config.yaml"    #Determines where Runner config will be stored
SERVICE_PATH="/opt/circleci/circleci.service"           #Determines where the Runner service definition will be stored


AUTH_TOKEN=${auth_token}
RUNNER_NAME=${runner_name}

#-------------------------------------------------------------------------------
# Update; install tools
#-------------------------------------------------------------------------------

yum update -y
yum install -y tar gzip coreutils git



#-------------------------------------------------------------------------------
# Download, install, and verify the binary
#-------------------------------------------------------------------------------

mkdir -p "$prefix/workdir"
base_url="https://circleci-binary-releases.s3.amazonaws.com/circleci-launch-agent"
echo "Determining latest version of CircleCI Launch Agent"
agent_version=$(curl "$base_url/release.txt")
echo "Using CircleCI Launch Agent version $agent_version"
echo "Downloading and verifying CircleCI Launch Agent Binary"
curl -sSL "$base_url/$agent_version/checksums.txt" -o checksums.txt
file="$(grep -F "$platform" checksums.txt | cut -d ' ' -f 2 | sed 's/^.//')"
mkdir -p "$platform"
echo "Downloading CircleCI Launch Agent: $file"
curl --compressed -L "$base_url/$agent_version/$file" -o "$file"
echo "Verifying CircleCI Launch Agent download"
grep "$file" checksums.txt | sha256sum --check && chmod +x "$file"; sudo cp "$file" "$prefix/circleci-launch-agent" || echo "Invalid checksum for CircleCI Launch Agent, please try download again"


#-------------------------------------------------------------------------------
# Install the CircleCI runner configuration
#-------------------------------------------------------------------------------

cat << EOF >$CONFIG_PATH
api:
  auth_token: $AUTH_TOKEN
runner:
  name: $RUNNER_NAME
  command_prefix: ["sudo", "-niHu", "circleci", "--"]
  working_directory: /opt/circleci/workdir/%s
  cleanup_working_directory: true
EOF

# Set correct config file permissions and ownership
chown root: /opt/circleci/launch-agent-config.yaml
chmod 600 /opt/circleci/launch-agent-config.yaml



#-------------------------------------------------------------------------------
# Create the circleci user & working directory - CentOS/RHEL
#-------------------------------------------------------------------------------

id -u circleci &>/dev/null || adduser --uid 1500 -c GECOS circleci

mkdir -p /opt/circleci/workdir
chown -R circleci /opt/circleci/workdir



#-------------------------------------------------------------------------------
# Create the circleci user & working directory - CentOS/RHEL
#-------------------------------------------------------------------------------

cat << EOF >$SERVICE_PATH
[Unit]
Description=CircleCI Runner
After=network.target
[Service]
ExecStart=/opt/circleci/circleci-launch-agent --config $CONFIG_PATH
Restart=always
User=root
NotifyAccess=exec
TimeoutStopSec=18300
[Install]
WantedBy = multi-user.target
EOF

#Enable service and start
systemctl enable $prefix/circleci.service
systemctl start circleci.service