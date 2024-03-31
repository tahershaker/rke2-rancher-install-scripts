#!/usr/bin/env bash

#=====================

#######################################################
###     This script will be used to bootstrap       ###
###   the Worker Node in an RKE2 Environment with   ###
### the required configuration and setup/configure  ###
###          required software and tools            ###
#######################################################

# Log command executions
set -x

#------------------------------------------------------

# Set required variables
export KUBEVERSION="1.26.10-1.1"
export KUBE_VERSION_SHORT="v1.26"
export MASTER_PRIV_IP="10.10.10.162"
export WORKER_01_IP="10.10.10.53"
export BASTION_NOST_IP="10.10.1.138"
export STAGE_MASTER_IP="10.10.13.105"
export STAGE_WORKER_IP="10.10.13.10"
export BASTION_NOST_FQDN="demo-a-bastion-01.rancher-demo.io"
export BASTION_NOST_FQDN_SHORT="demo-a-bastion-01"
export MASTER_NODE_FQDN="demo-a-mgmt-master-01.rancher-demo.io"
export MASTER_NODE_FQDN_SHORT="demo-a-mgmt-master-01"
export WORKER_NODE_FQDN="demo-a-mgmt-worker-01.rancher-demo.io"
export WORKER_NODE_FQDN_SHORT="demo-a-mgmt-worker-01"
export STAGE_MASTER_FQDN="demo-a-stage-master-01.rancher-demo.io"
export STAGE_MASTER_FQDN_SHORT="demo-a-stage-master-01"
export STAGE_WORKER_FQDN="demo-a-stage-worker-01.rancher-demo.io"
export STAGE_WORKER_FQDN_SHORT="demo-a-stage-worker-01"

#------------------------------------------------------

# Configure Hostname and /etc/hosts file

# Set the Hostnames to preserve after rebooting
sudo sed -i 's\preserve_hostname: false\preserve_hostname: true\g' /etc/cloud/cloud.cfg

# Set Hostname
sudo hostnamectl set-hostname $STAGE_WORKER_FQDN

# Edit the /etc/hosts file to add the local hostname
sudo sed -i "s\127.0.0.1 localhost\127.0.0.1  $STAGE_WORKER_FQDN $STAGE_WORKER_FQDN_SHORT\g" /etc/hosts
# Edit the /etc/hosts file to add other hostname
sudo cat << EOF >> /etc/hosts
$BASTION_NOST_IP         $BASTION_NOST_FQDN $BASTION_NOST_FQDN_SHORT
$WORKER_01_IP         $WORKER_NODE_FQDN $WORKER_NODE_FQDN_SHORT
$MASTER_PRIV_IP         $MASTER_NODE_FQDN $MASTER_NODE_FQDN_SHORT
$STAGE_MASTER_IP         $STAGE_MASTER_FQDN $STAGE_MASTER_FQDN_SHORT
EOF

#------------------------------------------------------

# Perform Kubernetes Installation Prerequisits

# Disable Swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

#Set up the IPV4 bridge on all nodes
sudo cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

#------------------------------------------------------

#Install containerd 
sudo apt-get update && sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update && sudo apt install -y containerd.io

# Configure containerd so that it starts using systemd as cgroup.
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd
 
#------------------------------------------------------

# Installa Kubernetes

# Add Apt Repository for Kubernetes
sudo mkdir /etc/apt/keyrings
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBE_VERSION_SHORT/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBE_VERSION_SHORT/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubelet, Kubeadm, and Kubectl
sudo apt-get update && sudo apt-get install -y kubelet=${KUBEVERSION} kubeadm=${KUBEVERSION} kubectl=${KUBEVERSION} --allow-change-held-packages
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

#------------------------------------------------------------