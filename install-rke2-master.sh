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
export MASTER_PUB_IP="3.10.126.243"
export MASTER_PRIV_IP="10.10.10.162"
export WORKER_01_IP="10.10.10.53"
export BASTION_NOST_IP="10.10.1.138"
export BASTION_NOST_FQDN="demo-a-bastion-01.rancher-demo.io"
export BASTION_NOST_FQDN_SHORT="demo-a-bastion-01"
export MASTER_NODE_FQDN="demo-a-mgmt-master-01.rancher-demo.io"
export MASTER_NODE_FQDN_SHORT="demo-a-mgmt-master-01"
export WORKER_NODE_FQDN="demo-a-mgmt-worker-01.rancher-demo.io"
export WORKER_NODE_FQDN_SHORT="demo-a-mgmt-worker-01"
export MASTER_NODE_LB_FQDN="demo-a-mgmt-master-01.3-10-126-243.sslip.io"
export RANCHER_MGMT_FQDN="rancher-manager.3-10-126-243.sslip.io"
export BUCKET_NAME="demo-a-bucket-01"
export BUCKET_END_POINT="s3.eu-west-2.amazonaws.com"
export REGION="eu-west-2"
export S3_USER_ACCESS_KEY="xxx="
export S3_USER_ACCESS_SECRET_KEY="xxx"
export KEYCLOAK_URL="http://keycloak.3-10-126-243.sslip.io"
export KEYCLOAK_AUTH_URL="http://keycloak.3-10-126-243.sslip.io/auth"

#---------------------------------------------------------------------------

# Edit /etc/hosts
cat << EOF >> /etc/hosts
$BASTION_NOST_IP         $BASTION_NOST_FQDN $BASTION_NOST_FQDN_SHORT
$WORKER_01_IP         $WORKER_NODE_FQDN $WORKER_NODE_FQDN_SHORT
EOF

### Create required directories

# Create a directory for the Yaml Files
mkdir -p yaml-files

# Create a directory for the Helm Charts Vlaues Files
mkdir -p helm-values-files

# Create a directory for the keycloak Helm Charts Vlaues Files
mkdir -p helm-values-files/keycloak

# Create RKE configuration directory
mkdir -p /etc/rancher/rke2/

# Create the manifest directory for RKE2 Helm Charts
mkdir -p /var/lib/rancher/rke2/server/manifests/

#---------------------------------------------------------------------------

### Create required files with its contents

# Create the Rancher Backup S3 User Access Yaml File
cat << EOF >> yaml-files/rancher-backup-s3-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: s3-creds
type: Opaque
data:
  accessKey: "${S3_USER_ACCESS_KEY}"
  secretKey: "${S3_USER_ACCESS_SECRET_KEY}"
EOF

# Create the Rancher encruption provider config File
cat << EOF >> yaml-files/encryption-provider-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aesgcm:
          keys:
            - name: key1
              secret: c2VjcmV0IGlzIHNlY3VyZQ==
EOF

# Create the cluster storage class
cat << EOF >> yaml-files/storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
EOF

# Create the Keycloak PersistentVolume
cat << EOF >> yaml-files/keycloak-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: keycloak-pv
  namespace: keycloak
spec:
  storageClassName: local-storage
  claimRef:
    name: keycloak-volume
    namespace: keycloak
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  local:
    path: /mnt/
  nodeAffinity:
   required:
    nodeSelectorTerms:
    - matchExpressions:
      - key: kubernetes.io/hostname
        operator: In
        values:
        - $WORKER_NODE_FQDN
EOF

# Create the Keycloak PersistentVolumeClaim
cat << EOF >> yaml-files/keycloak-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: keycloak-volume
  namespace: keycloak
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-storage
EOF

# Create the Keycloak Helm Value Files
cat << EOF >> helm-values-files/keycloak/valuse.yaml
replicas: 1
extraEnv: |
  - name: KEYCLOAK_USER
    value:  demo-admin
  - name: KEYCLOAK_PASSWORD
    value: RancherDemo@123
  - name: KEYCLOAK_FRONTEND_URL
    value: "$KEYCLOAK_AUTH_URL"
ingress:
  enabled: true
  ingressClassName: "nginx"
  servicePort: http
  annotations:
    ingress.kubernetes.io/affinity: cookie
    nginx.ingress.kubernetes.io/proxy-buffer-size: 128k
  rules:
    -
      host: $KEYCLOAK_URL
      paths:
        - path: /
          pathType: Prefix
postgresql:
  enabled: true
  postgresqlUsername: keycloak
  postgresqlPassword: keycloak
  postgresqlDatabase: keycloak
  networkPolicy:
    enabled: false
  persistence:
    existingClaim: keycloak-volume
EOF

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
    hostname: "$RANCHER_MGMT_FQDN"
    bootstrapPassword: "RancherDemo@123"
    replicas: 1
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

# Create a Helm Chart to deploy Rancher Backup CRDs
cat << EOF >> /var/lib/rancher/rke2/server/manifests/rke2-rancher-backup-crd.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: rancher-backup-crd
spec:
  chart: rancher-backup-crd
  repo: https://charts.rancher.io
  targetNamespace: cattle-resources-system
  createNamespace: true
EOF

# Create a Helm Chart to deploy Rancher Backup
cat << EOF >> /var/lib/rancher/rke2/server/manifests/rke2-rancher-backup.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: rancher-backup
spec:
  chart: rancher-backup
  repo: https://charts.rancher.io
  targetNamespace: cattle-resources-system
  createNamespace: true
  valuesContent: |-
    s3:
      enabled: true
      credentialSecretName: s3-creds
      credentialSecretNamespace: default
      bucketName: "${BUCKET_NAME}"
      endpoint: "${BUCKET_END_POINT}"
      insecureTLSSkipVerify: true
      region: "${REGION}"
    persistence:
      enabled: false
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
sleep 120

#---------------------------------------------------------------------------

### Perform required kubectl commands

# Create Keycloak Namespace
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml create namespace keycloak

# Create the Rancher Bakcup S3 Secret
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml apply -f yaml-files/rancher-backup-s3-secret.yaml

# Create the secret for the rancher backup encryption
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml create secret generic encryptionconfig --from-file=yaml-files/encryption-provider-config.yaml -n cattle-resources-system

# Create Storage Class
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml apply -f yaml-files/storage-class.yaml

# Create Keycloak PV
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml apply -f yaml-files/keycloak-pv.yaml

# Create keycloak PVC
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml apply -f yaml-files/keycloak-pvc.yaml

#---------------------------------------------------------------------------
