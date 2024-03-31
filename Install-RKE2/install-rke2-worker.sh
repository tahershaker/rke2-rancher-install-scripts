#!/usr/bin/env bash

#=====================

#######################################################
###     This script will be used to bootstrap       ###
###  the Worker Node in an RKE2 Environment with    ###
### the required configuration and setup/configure  ###
###          required software and tools            ###
#######################################################

# Log command executions
set -x

#------------------------------------------------------

# Set required variables
export MASTER_PRIV_IP="xxx"
export WORKER_01_IP="xxx"
export BASTION_NOST_IP="xxx"
export BASTION_NOST_FQDN="demo-a-bastion-01.rancher-demo.io"
export BASTION_NOST_FQDN_SHORT="demo-a-bastion-01"
export MASTER_NODE_FQDN="demo-a-mgmt-master-01.rancher-demo.io"
export MASTER_NODE_FQDN_SHORT="demo-a-mgmt-master-01"
export WORKER_NODE_FQDN="demo-a-mgmt-worker-01.rancher-demo.io"
export WORKER_NODE_FQDN_SHORT="demo-a-mgmt-worker-01"
export KUBE_VERSION="v1.26"


#---------------------------------------------------------------------------

# Edit /etc/hosts
cat << EOF >> /etc/hosts
$BASTION_NOST_IP         $BASTION_NOST_FQDN $BASTION_NOST_FQDN_SHORT
$MASTER_PRIV_IP         $MASTER_NODE_FQDN $MASTER_NODE_FQDN_SHORT
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
server: https://$MASTER_PRIV_IP:9345
token: SuseRKE2token!!5s84s9f9e3d2f2x3f1
EOF

# Install RKE2 agent
curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL=$KUBE_VERSION INSTALL_RKE2_TYPE="agent" sh -

# Enable and start RKE2 agent service
systemctl enable rke2-agent.service
systemctl start rke2-agent.service

# Install and configure Kuberctl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl