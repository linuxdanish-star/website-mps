#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^1\.[0-9]+$ ]]; then
    echo 'Usage: bash install-jenkins.sh <EKS minor version, for example 1.37>' >&2
    exit 2
fi
cluster_version="$1"

sudo apt-get update
sudo apt-get install -y ca-certificates curl unzip git openjdk-21-jre fontconfig
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
    -o /etc/apt/keyrings/jenkins-keyring.asc
printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' \
    | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
sudo apt-get update
sudo apt-get install -y jenkins

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
cd "$work_dir"

if ! command -v aws >/dev/null 2>&1; then
    curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscli.zip
    unzip -q awscli.zip
    sudo ./aws/install
fi

kubectl_version="$(curl -fsSL "https://dl.k8s.io/release/stable-$cluster_version.txt")"
kubectl_url="https://dl.k8s.io/release/$kubectl_version/bin/linux/amd64/kubectl"
curl -fsSL "$kubectl_url" -o kubectl
curl -fsSL "$kubectl_url.sha256" -o kubectl.sha256
printf '%s  kubectl\n' "$(cat kubectl.sha256)" | sha256sum --check
sudo install -m 0755 kubectl /usr/local/bin/kubectl
sudo systemctl enable --now jenkins

aws --version
kubectl version --client
sudo systemctl is-active jenkins
