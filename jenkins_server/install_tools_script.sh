#!/bin/bash


# This script is intended to run as root (e.g., via EC2 user‑data).
# No auto‑elevation is performed because user‑data already executes as root.

set -e

# Ensure locally installed binaries are in PATH
export PATH="/usr/local/bin:$PATH"

LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "Starting DevOps tools installation..."

########################################
# System update
########################################
apt-get update -y
apt-get upgrade -y

apt-get install -y \
    curl \
    unzip \
    gnupg \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    wget \
    git \
    fontconfig \
    openjdk-21-jdk

########################################
# Install Docker
########################################
echo "Installing Docker..."

# Add Docker's official GPG key:
apt update -y
install -m 0755 -d /etc/apt/keyrings 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt update -y

apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin  -y


systemctl enable docker
systemctl start docker

########################################
# Allow ubuntu & jenkins users Docker access
########################################
usermod -aG docker ubuntu || true
usermod -aG docker jenkins || true

########################################
# Install AWS CLI v2
########################################
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
-o awscliv2.zip

unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

########################################
# Install kubectl
########################################
curl -LO "https://dl.k8s.io/release/$(curl -L -s \
https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

########################################
# Install eksctl
########################################
curl --silent --location \
"https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
| tar xz -C /tmp

mv /tmp/eksctl /usr/local/bin

########################################
# Install Helm
########################################
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

########################################
# Install Terraform
########################################
wget -O- https://apt.releases.hashicorp.com/gpg \
| gpg --dearmor \
| tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
| tee /etc/apt/sources.list.d/hashicorp.list

apt-get update -y
apt-get install terraform -y

########################################
# Install Jenkins
########################################
wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
apt update -y
apt install jenkins -y



systemctl enable jenkins
systemctl start jenkins

########################################
# Verify installations
########################################
echo "Installed versions:"

docker --version
aws --version
kubectl version --client
eksctl version
helm version
terraform version
java -version

echo "Jenkins initial admin password:"
cat /var/lib/jenkins/secrets/initialAdminPassword

echo "All tools installed successfully ✅"