#!/usr/bin/env bash

#!/usr/bin/env bash

#=====================

#######################################################
###     This script will be used to bootstrap       ###
###   the Master Node in the RKE2 Environment and   ###
###  Install Rancher with the required helm charts  ###
#######################################################

# Log command executions
set -x

#------------------------------------------------------

# Set required variables
export RANCHER_MGMT_FQDN="https://rancher-manager.13-42-21-57.sslip.io"


#---------------------------------------------------------------------------

### Configure Hostnames and DNS

# Configure hostname 
sudo hostnamectl set-hostname master-01.rke2-testing.io

#---------------------------------------------------------------------------

### Create required directories

# Create a directory for the Yaml Files
mkdir -p /home/ec2-user/yamlfiles

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
EOF

#---------------------------------------------------------------------------

### Install required tools

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

#---------------------------------------------------------------------------

### Create Helm Chart Files in the RKE2 Manifest directory to deploy required applications

# Create a Helm Chart to deploy cert-manager and add it to RKE2 manifest
cat << EOF >> /var/lib/rancher/rke2/server/manifests/rke2-cert-manager.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cert-manager
spec:
  chart: cert-manager
  repo: https://charts.jetstack.io
  targetNamespace: cert-manager
  createNamespace: true
  version: v1.13.0
  set:
    installCRDs: "true"
EOF

# Create a Helm Chart to deploy Rancher Manager
cat << EOF >> /var/lib/rancher/rke2/server/manifests/rke2-rancher-manager.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: rancher
spec:
  repo: https://charts.rancher.com/server-charts/prime
  chart: rancher
  targetNamespace: cattle-system
  createNamespace: true
  version: v2.8.2
  set:
    hostname: "${RANCHER_MGMT_FQDN}"
    bootstrapPassword: "RancherDemo@123"
EOF

# Create a Helm Chart to deploy Rancher CSI Benchmarks CRDs
cat << EOF >> /var/lib/rancher/rke2/server/manifests/rke2-csi-benchmark-crd.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: rancher-cis-benchmark-crd
spec:
  chart: rancher-cis-benchmark-crd
  repo: https://charts.rancher.io
  targetNamespace: cis-operator-system
  createNamespace: true
EOF

# Create a Helm Chart to deploy Rancher CSI Benchmarks
cat << EOF >> /var/lib/rancher/rke2/server/manifests/rke2-csi-benchmark.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: rancher-cis-benchmark
spec:
  chart: rancher-cis-benchmark
  repo: https://charts.rancher.io
  targetNamespace: cis-operator-system
  createNamespace: true
EOF

#---------------------------------------------------------------------------

### Install RKE2

# Install RKE2 server
curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL="v1.26" INSTALL_RKE2_TYPE="server" sh -

# Enable and start RKE2 server service
systemctl enable rke2-server.service
systemctl start rke2-server.service

# Install and configure Kuberctl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
mkdir -p ~/.kube
ln -s /etc/rancher/rke2/rke2.yaml ~/.kube/config

#---------------------------------------------------------------------------

# Sleep for 3 minutes to make sure all previous executions are completed
sleep 180

#---------------------------------------------------------------------------

### Perform required kubectl commands


#---------------------------------------------------------------------------
