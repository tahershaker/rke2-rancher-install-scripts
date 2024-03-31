#!/usr/bin/env bash

#=====================

#######################################################
###     This script will be used to bootstrap       ###
###   the Master Node in an RKE2 Environment with   ###
### the required configuration and setup/configure  ###
###          required software and tools            ###
#######################################################

# Log command executions
set -x

#------------------------------------------------------

# Set required variables
export MASTER_PUB_IP="xxx"
export MASTER_PRIV_IP="xxx"
export WORKER_01_IP="xxx"
export BASTION_NOST_IP="xxx"
export BASTION_NOST_FQDN="demo-a-bastion-01.rancher-demo.io"
export BASTION_NOST_FQDN_SHORT="demo-a-bastion-01"
export MASTER_NODE_FQDN="demo-a-mgmt-master-01.rancher-demo.io"
export MASTER_NODE_FQDN_SHORT="demo-a-mgmt-master-01"
export WORKER_NODE_FQDN="demo-a-mgmt-worker-01.rancher-demo.io"
export WORKER_NODE_FQDN_SHORT="demo-a-mgmt-worker-01"
export MASTER_NODE_LB_FQDN="demo-a-mgmt-master-01.xxx.sslip.io"
export KUBE_VERSION="v1.26"

#---------------------------------------------------------------------------

# Edit /etc/hosts
cat << EOF >> /etc/hosts
$BASTION_NOST_IP         $BASTION_NOST_FQDN $BASTION_NOST_FQDN_SHORT
$WORKER_01_IP         $WORKER_NODE_FQDN $WORKER_NODE_FQDN_SHORT
EOF

### Create required directories

# Create RKE configuration directory
mkdir -p /etc/rancher/rke2/

# Create the manifest directory for RKE2 Helm Charts
mkdir -p /var/lib/rancher/rke2/server/manifests/

#---------------------------------------------------------------------------

### Create required files with its contents

# Create the RKE2 Configuration file
cat << EOF >> /etc/rancher/rke2/config.yaml
write-kubeconfig-mode: "0644"
cni: "calico"
cluster-cidr: "172.16.0.0/16"
service-cidr: "172.17.0.0/16"
token: SuseRKE2token!!5s84s9f9e3d2f2x3f1
tls-san:
  - $MASTER_NODE_LB_FQDN
  - $MASTER_PUB_IP
  - $MASTER_PRIV_IP
EOF

#---------------------------------------------------------------------------

### Install required tools

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

#---------------------------------------------------------------------------

### Install RKE2

# Install RKE2 server
curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL=$KUBE_VERSION INSTALL_RKE2_TYPE="server" sh -

# Enable and start RKE2 server service
systemctl enable rke2-server.service
systemctl start rke2-server.service

# Install and configure Kuberctl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
mkdir -p ~/.kube
ln -s /etc/rancher/rke2/rke2.yaml ~/.kube/config

#---------------------------------------------------------------------------
