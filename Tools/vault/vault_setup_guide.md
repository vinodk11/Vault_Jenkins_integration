# HashiCorp Vault HA + Jenkins Integration on kubeadm Kubernetes Cluster

# Overview

This document explains how to:

- Deploy HashiCorp Vault HA on a kubeadm Kubernetes cluster
- Configure Raft storage
- Initialize and unseal Vault
- Enable Kubernetes authentication
- Configure Jenkins integration with Vault
- Retrieve secrets dynamically inside Jenkins pipelines

Environment:

- kubeadm Kubernetes cluster on EC2
- Jenkins deployed in namespace `jenkins`
- Vault deployed in namespace `vault`
- Ingress NGINX already installed

---

# Architecture

```text
Jenkins Pod
   |
   |--> Kubernetes Service Account JWT
              |
              |--> Vault Kubernetes Authentication
                          |
                          |--> Vault Role
                                      |
                                      |--> Vault Policies
                                                  |
                                                  |--> Vault Secrets
```

---

# 1. Create Vault Namespace

```bash
kubectl create namespace vault
```

---

# 1.1 Install HELM
```bash
sudo apt update && sudo apt upgrade -y
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

wget https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz
tar -zxvf helm-v3.14.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
helm version
```

---

# 2. Add HashiCorp Helm Repository
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

---

# 3. Create Vault Values File

Create:

```bash
vi vault-values.yaml
```

Paste:

```yaml
global:
  enabled: true

injector:
  enabled: true

ui:
  enabled: true

server:
  image:
    repository: hashicorp/vault
    tag: "1.18.1"

  service:
    enabled: true
    type: ClusterIP

  extraEnvironmentVars:
    VAULT_LOG_LEVEL: "debug"

  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: local-path
    accessMode: ReadWriteOnce

  ha:
    enabled: true
    replicas: 3

    raft:
      enabled: true

      config: |
        ui = true

        listener "tcp" {
          address = "0.0.0.0:8200"
          cluster_address = "0.0.0.0:8201"
          tls_disable = 1
        }

        storage "raft" {
          path = "/vault/data"

          retry_join {
            leader_api_addr = "http://vault-0.vault-internal:8200"
          }

          retry_join {
            leader_api_addr = "http://vault-1.vault-internal:8200"
          }

          retry_join {
            leader_api_addr = "http://vault-2.vault-internal:8200"
          }
        }

        service_registration "kubernetes" {}
```

---

# 4. Install Vault

```bash
helm install vault hashicorp/vault \
  --namespace vault \
  -f vault-values.yaml
```

---
# 5. configure ingress vault

create vault ingress yml 

```bash
vi vault-ingress.yml
```

```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault
  namespace: vault
spec:
  ingressClassName: nginx

  rules:
  - host: vault.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: vault
            port:
              number: 8200
```

```bash
kubectl apply -f vault-ingress.yml
```
---

# 5. Verify Vault Pods

```bash
kubectl get pods -n vault
```

Expected:

```text
vault-0
vault-1
vault-2
```

---

# 6. Initialize Vault (RUN ONLY ONCE)

```bash
kubectl exec -it vault-0 -n vault -- vault operator init
```

This generates:

- Unseal Keys
- Root Token

Store them safely.

---

# 7. Unseal Vault Pods

## Unseal vault-0

```bash
kubectl exec -n vault -it vault-0 -- vault operator unseal <KEY_1>
```

```bash
kubectl exec -n vault -it vault-0 -- vault operator unseal <KEY_2>
```

```bash
kubectl exec -n vault -it vault-0 -- vault operator unseal <KEY_3>
```

---

## Unseal vault-1

```bash
kubectl exec -n vault -it vault-1 -- vault operator unseal <KEY_1>
```

```bash
kubectl exec -n vault -it vault-1 -- vault operator unseal <KEY_2>
```

```bash
kubectl exec -n vault -it vault-1 -- vault operator unseal <KEY_3>
```

---

## Unseal vault-2

```bash
kubectl exec -n vault -it vault-2 -- vault operator unseal <KEY_1>
```

```bash
kubectl exec -n vault -it vault-2 -- vault operator unseal <KEY_2>
```

```bash
kubectl exec -n vault -it vault-2 -- vault operator unseal <KEY_3>
```

---

# 8. Verify Vault HA Cluster

```bash
kubectl exec -n vault -it vault-0 -- vault operator raft list-peers
```

Expected:

```text
vault-0   leader
vault-1   follower
vault-2   follower
```

---

# 9. Login to Vault

```bash
kubectl exec -n vault -it vault-0 -- vault login <ROOT_TOKEN>
```

---

# 10. Verify Authentication Methods

```bash
kubectl exec -n vault -it vault-0 -- vault auth list
```

---

# 11. Enable Kubernetes Authentication

```bash
kubectl exec -n vault -it vault-0 -- vault auth enable kubernetes
```

If already enabled, ignore the error.

---

# 12. Configure Kubernetes Authentication Backend

Vault needs:

- Kubernetes API endpoint
- Kubernetes CA certificate
- Token reviewer JWT

This allows Vault to validate Kubernetes service account tokens.

---

## Get Kubernetes API Server

```bash
KUBE_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath="{.clusters[0].cluster.server}")
```

---

## Get Token Reviewer JWT

```bash
TOKEN_REVIEW_JWT=$(kubectl exec -n vault vault-0 -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)
```

---

## Get Kubernetes CA Certificate

```bash
KUBE_CA_CERT=$(kubectl exec -n vault vault-0 -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)
```

---

## Configure Vault Kubernetes Authentication

```bash
kubectl exec -i -n vault vault-0 -- vault write auth/kubernetes/config \
  token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
  kubernetes_host="$KUBE_HOST" \
  kubernetes_ca_cert="$KUBE_CA_CERT"
```

---

# 13. Verify Kubernetes Auth Configuration

```bash
kubectl exec -n vault -it vault-0 -- vault read auth/kubernetes/config
```

IMPORTANT:

You should see:

```text
token_reviewer_jwt_set    true
```

---

# 14. Enable KV Version 2 Secrets Engine

```bash
kubectl exec -n vault -it vault-0 -- vault secrets enable -path=secret kv-v2
```

If already enabled, ignore the error.

---

# 15. Create Jenkins Secret

```bash
kubectl exec -n vault -it vault-0 -- vault kv put secret/jenkins \
  username=admin \
  password=SuperSecret123
```

Explanation:

This stores a test secret in Vault.

Secret path:

```text
secret/data/jenkins
```

---

# 16. Verify Secret

```bash
kubectl exec -n vault -it vault-0 -- vault kv get secret/jenkins
```

---

# 17. Create Jenkins Vault Policy

Create policy file:

```bash
cat <<EOF > jenkins-policy.hcl
path "secret/data/jenkins" {
  capabilities = ["read"]
}

path "secret/metadata/jenkins" {
  capabilities = ["read", "list"]
}
EOF
```

Explanation:

- `secret/data/jenkins` allows reading secret data
- `secret/metadata/jenkins` allows KV v2 metadata access

Both are required for Jenkins Vault plugin.

---

# 18. Copy Policy File to Vault Pod

```bash
kubectl cp jenkins-policy.hcl vault/vault-0:/tmp/
```

---

# 19. Apply Jenkins Policy

```bash
kubectl exec -n vault -it vault-0 -- vault policy write jenkins-policy /tmp/jenkins-policy.hcl
```

---

# 20. Create Jenkins Kubernetes Role

```bash
kubectl exec -n vault -it vault-0 -- vault write auth/kubernetes/role/jenkins \
  bound_service_account_names=jenkins \
  bound_service_account_namespaces=jenkins \
  policies=jenkins-policy \
  ttl=24h
```

Explanation:

This maps:

- Kubernetes Service Account: `jenkins`
- Namespace: `jenkins`
- Vault Policy: `jenkins-policy`

---

# 21. Verify Jenkins Role

```bash
kubectl exec -n vault -it vault-0 -- vault read auth/kubernetes/role/jenkins
```

---

# 22. Verify Jenkins Service Account

```bash
kubectl describe pod jenkins-0 -n jenkins | grep -i "Service Account"
```

Expected:

```text
Service Account: jenkins
```

IMPORTANT:

This must match:

```text
bound_service_account_names=jenkins
```

---

# 23. Install Jenkins Plugins

In Jenkins UI:

```text
Manage Jenkins
→ Plugins
→ Available Plugins
```

Install:

- HashiCorp Vault Plugin
- HashiCorp Vault Pipeline Plugin

Restart Jenkins.

---

###### 24. Configure Vault in Jenkins

Go to:

```text
Manage Jenkins
→ System
→ HashiCorp Vault
```

Configure:

| Setting | Value |
|---|---|
| Vault URL | http://vault.vault:8200 |
| Engine Version | 2 |
| Prefix Path | EMPTY |
| Vault Credential | vault-k8s |

IMPORTANT:

Leave Prefix Path EMPTY.

---

##### 25. Create Vault Kubernetes Credential

Go to:

```text
Manage Jenkins
→ Credentials
→ System
→ Global credentials
→ Add Credentials
```

Configure:

| Field | Value |
|---|---|
| Kind | Vault Kubernetes Credential |
| Role | jenkins |
| Mount Path | kubernetes |
| ID | vault-k8s |

Namespace field:

Leave EMPTY.

---

#### 26. Jenkins Pipeline Example

```groovy
pipeline {
    agent any

    stages {
        stage('Read Secret') {
            steps {
                withVault(
                    configuration: [
                        vaultUrl: 'http://vault.vault:8200',
                        vaultCredentialId: 'vault-k8s',
                        engineVersion: 2
                    ],
                    vaultSecrets: [[
                        path: 'secret/jenkins',
                        secretValues: [
                            [vaultKey: 'username', envVar: 'USERNAME'],
                            [vaultKey: 'password', envVar: 'PASSWORD']
                        ]
                    ]]
                ) {
                    sh '''
                    if [ -n "$USERNAME" ]; then
                       echo "Username received from Vault"
                    fi

                    if [ -n "$PASSWORD" ]; then
                        echo "Password received from Vault"
                    fi
                    '''
                }
            }
        }
    }
}
```

---

# Expected Output

```text
admin
SuperSecret123
```

---

# Important Notes

## Why Prefix Path Must Be Empty

The Jenkins Vault plugin internally constructs KV v2 paths.

If Prefix Path is configured incorrectly, Jenkins may generate invalid paths like:

```text
secret/data/jenkins/secret/jenkins
```

Leaving Prefix Path empty avoids this issue.

---

# Real Production Use Cases

Instead of test credentials, Vault can store:

- DockerHub credentials
- Nexus credentials
- SonarQube tokens
- AWS credentials
- SSH keys
- Database passwords
- GitHub Personal Access Tokens

---

# Useful Vault Commands

## Check Vault Status

```bash
kubectl exec -n vault -it vault-0 -- vault status
```

---

## Check Vault Token

```bash
kubectl exec -n vault -it vault-0 -- vault token lookup
```

---

## Check Raft Peers

```bash
kubectl exec -n vault -it vault-0 -- vault operator raft list-peers
```

---

## Check Vault Logs

```bash
kubectl logs vault-0 -n vault
```

---

# Final Architecture

```text
kubeadm Cluster
   |
   |-- Jenkins
   |-- SonarQube
   |-- Nexus
   |-- Vault HA
   |-- Ingress NGINX
```

---

# Recommended Improvements

## Enable TLS

Current config:

```hcl
tls_disable = 1
```

Only suitable for labs/testing.

---

## Configure Auto Unseal

Recommended:

- AWS KMS Auto Unseal

Avoids manual unseal operations.

---

## Use EBS CSI Driver

For production storage:

- Use AWS EBS CSI Driver
- Use gp3 StorageClass

instead of local-path storage.

---

# Conclusion

You now have:

- Vault HA cluster using Raft
- Kubernetes authentication
- Jenkins integration with Vault
- Dynamic secret retrieval
- Enterprise-style DevOps security architecture



```bash
kubectl exec -n vault -it vault-0 sh

$ vault kv put secret/dockerhub username=vinod1188  password=V!nnu@1188

vault kv get secret/dockerhub
```


```bash
vault kv put secret/sonarqube token=squ_ed67ac61ab0262e106a344be2048f818d3a47b09
vault kv get secret/sonarqube
```

```bash
vault kv put secret/nexus \
  username=admin \
  password=Ag@sthy@123456

vault kv get secret/nexus
```

```bash
cat <<EOF > jenkins-policy.hcl
path "secret/data/jenkins" {
  capabilities = ["read"]
}

path "secret/metadata/jenkins" {
  capabilities = ["read", "list"]
}

path "secret/data/dockerhub" {
  capabilities = ["read"]
}

path "secret/metadata/dockerhub" {
  capabilities = ["read", "list"]
}

path "secret/data/sonarqube" {
  capabilities = ["read"]
}

path "secret/metadata/sonarqube" {
  capabilities = ["read", "list"]
}

path "secret/data/nexus" {
  capabilities = ["read"]
}

path "secret/metadata/nexus" {
  capabilities = ["read", "list"]
}
EOF
```

```bash
kubectl cp jenkins-policy.hcl vault/vault-0:/tmp/

kubectl exec -n vault -it vault-0 -- \
vault policy write jenkins-policy /tmp/jenkins-policy.hcl
```

