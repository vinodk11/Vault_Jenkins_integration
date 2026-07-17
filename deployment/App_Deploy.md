🚀 Secure Application Deployment with Jenkins & HashiCorp Vault

In this section, you'll configure HashiCorp Vault to securely manage application and database secrets, enable Kubernetes authentication, and deploy the Bank Application using a Jenkins CI/CD pipeline.

The application retrieves its sensitive configuration directly from Vault at runtime using the **Vault Agent Injector**, ensuring that no secrets are stored in source code, Kubernetes manifests, or container images.

---

# 🔐 Step 1: Create the Vault Policy

Create a Vault policy that grants the application permission to access only the required secrets.

Create a file named **`webapps-policy.hcl`**

```bash
cat <<EOF > webapps-policy.hcl
# Database Secrets
path "secret/data/mysql" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

# Application Secrets
path "secret/data/frontend" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

# Allow listing secret metadata
path "secret/metadata/mysql" {
  capabilities = ["list"]
}

path "secret/metadata/frontend" {
  capabilities = ["list"]
}
EOF
```

Upload the policy to Vault and apply it.

```bash
kubectl cp webapps-policy.hcl vault/vault-0:/tmp/webapps-policy.hcl

kubectl exec -n vault -it vault-0 -- \
vault policy write webapps-policy /tmp/webapps-policy.hcl
```

> 💡 **Why is this policy required?**
>
> Vault policies control which secrets an application is allowed to access. Following the **Principle of Least Privilege**, the application receives access only to the secrets it needs.

---

# ☸️ Step 2: Create the Vault Kubernetes Role

Next, map the Kubernetes ServiceAccount used by the application to the Vault policy.

```bash
kubectl exec -n vault -it vault-0 -- \
vault write auth/kubernetes/role/vault-role \
bound_service_account_names=vault-auth \
bound_service_account_namespaces="webapps" \
policies=webapps-policy \
ttl=24h
```

### Configuration Overview

| Parameter | Description |
|-----------|-------------|
| `bound_service_account_names` | Kubernetes ServiceAccount used by the application Pods |
| `bound_service_account_namespaces` | Namespace where the application is deployed |
| `policies` | Vault policy assigned after successful authentication |
| `ttl` | Lifetime of the Vault token issued to the application |

---

# 🔑 Step 3: Store Application Secrets

Store the database and application credentials securely inside Vault.

### MySQL Secrets

```bash
kubectl exec -n vault -it vault-0 -- \
vault kv put secret/mysql \
MYSQL_DATABASE=bankappdb \
MYSQL_ROOT_PASSWORD=Test@123
```

### Application Secrets

```bash
kubectl exec -n vault -it vault-0 -- \
vault kv put secret/frontend \
MYSQL_ROOT_PASSWORD=Test@123
```

Verify the stored secrets.

```bash
vault kv get secret/mysql

vault kv get secret/frontend
```

---

# 📄 Step 4: Configure Vault Agent Injection

The application Pods use the **Vault Agent Injector** to retrieve secrets automatically.

Instead of embedding passwords inside Kubernetes manifests, Vault injects the secrets into the Pod during startup.

---

## 🛢️ MySQL Deployment

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "vault-role"

  vault.hashicorp.com/agent-inject-secret-MYSQL_ROOT_PASSWORD: "secret/data/mysql"

  vault.hashicorp.com/agent-inject-template-MYSQL_ROOT_PASSWORD: |
    {{- with secret "secret/data/mysql" -}}
    export MYSQL_ROOT_PASSWORD="{{ .Data.data.MYSQL_ROOT_PASSWORD }}"
    {{- end }}
```

---

## 🌐 Bank Application Deployment

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "vault-role"

  vault.hashicorp.com/agent-inject-secret-SPRING_DATASOURCE_PASSWORD: "secret/data/frontend"

  vault.hashicorp.com/agent-inject-template-SPRING_DATASOURCE_PASSWORD: |
    {{- with secret "secret/data/frontend" -}}
    export SPRING_DATASOURCE_PASSWORD="{{ .Data.data.MYSQL_ROOT_PASSWORD }}"
    {{- end }}
```

---

## 📝 Understanding the Vault Annotations

| Annotation                | Description                                        
|---------------------------|------------------                                       
| `agent-inject`            | Enables the Vault Agent Injector for the Pod       
| `role`                    | Vault Kubernetes role used for authentication      
| `agent-inject-secret-*`   | Specifies which Vault secret should be retrieved   
| `agent-inject-template-*` | Formats the retrieved secret before injecting it into the container 

---

### 🔄 What happens behind the scenes?

When the Pod starts:

1. ☸️ Kubernetes authenticates the Pod using its ServiceAccount.
2. 🔐 Vault verifies the ServiceAccount against the configured Kubernetes Role.
3. 🎫 Vault issues a temporary token.
4. 📥 Vault Agent retrieves the requested secrets.
5. 📄 Secrets are written into `/vault/secrets/`.
6. 🚀 The application reads the secrets at startup.

This approach ensures that sensitive credentials are **never stored inside GitHub, Docker images, or Kubernetes manifests**.
---

# 🚀 Create the Application Build Pipeline

From the Jenkins Dashboard:

📂 **New Item**

Enter the name:

```text
Application-Build-Pipeline
```

Select

```text
Pipeline
```

Click **OK**

---
# 🗂️ General Settings

Under **General**, enable:

* ✅ Discard old builds

Then configure **Log Rotation**:

| Setting                 | Value       |
| ----------------------- | ----------- |
| 🗓️ Days to keep builds | Leave Blank |
| 📦 Max builds to keep   | **3**       |

> 💡 **Why Log Rotation?**
>
> Log rotation automatically removes old build history, reducing disk usage and keeping Jenkins clean and efficient.
![Alt text](../content/16-51-07.png)
---

# 🔧 Pipeline Configuration

Scroll to the **Pipeline** section and configure the following:
Change the Definition dropdown to "pipeline script form SCM". 
 
| ⚙️ Field             | 📝 Value                       |
| -------------------- | ------------------------------ |
| Definition           | **Pipeline script from SCM**   |
| SCM                  | **Git**                        |
| Repository URL       | `<YOUR_GITHUB_REPOSITORY>`     |
| Credentials          | **None** *(Public Repository)* |
| Branch               | `*/main`                       |
| Script Path          | `Application/Jenkinsfile`      |
| Lightweight Checkout | ✅ Enabled                     |

![Alt text](../content/16-51-08.png)

After completing the configuration:

* 💾 Click **Apply**
* 💾 Click **Save**

---

# ▶️ Run the Pipeline

Click

```text
Build Now
```

The pipeline performs the following tasks automatically:

- 📥 Clone the application source code
- 🔐 Retrieve GitHub credentials from Vault
- 📦 Build the application using Maven
- 🔍 Perform SonarQube analysis
- 🛡️ Scan using Trivy
- 🐳 Build the Docker image
- 📤 Push the image to Docker Hub
- 📝 Update the Kubernetes manifest with the latest image tag

---

# 🌐 Access the Application

Since the application uses the same **AWS Application Load Balancer (ALB)** as the DevSecOps tools, map the ALB IP address to your local hostname.

Add the following entry to:

```bash
/etc/hosts
```

```
<ALB-IP>     bankapp.local
```

> 📌 If you haven't already resolved the ALB IP address, follow **🌍 Step 3 – Resolve the ALB DNS** in the **Tools Setup Guide**.

📖 See: **[Tools Setup Guide](../Tools/Tools_setup.md)**

Once updated, access the application:

```text
http://bankapp.local
```

🎉 Congratulations! Your Bank Application is now securely deployed on Amazon EKS using a complete DevSecOps CI/CD pipeline with Jenkins, Vault, SonarQube, Nexus, Trivy, Docker, and Kubernetes.
