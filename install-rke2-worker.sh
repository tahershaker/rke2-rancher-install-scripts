#!/usr/bin/env bash

#=====================

#######################################################
###     This script will be used to bootstrap       ###
### the Worker Node in the management cluster with  ###
### the required configuration and setup/configure  ###
###          required software and tools            ###
#######################################################

#------------------------------------------------------

# Configure hostname 
sudo hostnamectl set-hostname worker-01.rke2-testing.io

# Edit /etc/hosts
cat << EOF >> /etc/hosts
127.0.1.1          worker-01.rke2-testing.io
172.31.102.80         master-01.rke2-testing.io
EOF

# Install Helm
mkdir -p /opt/rancher/helm
cd /opt/rancher/helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 755 get_helm.sh && ./get_helm.sh
mv /usr/local/bin/helm /usr/bin/helm

# Create an RKE configuration file
mkdir -p /etc/rancher/rke2/
cat << EOF >> /etc/rancher/rke2/config.yaml
write-kubeconfig-mode: "0644"
server: https://master-01.rke2-testing.io.224:9345
token: SuseRKE2token!!5s84s9f9e3d2f2x3f1
EOF

# Install RKE2 agent
curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL="v1.26" INSTALL_RKE2_TYPE="agent" sh -

# Enable and start RKE2 agent service
systemctl enable rke2-agent.service
systemctl start rke2-agent.service

# Install and configure Kuberctl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl