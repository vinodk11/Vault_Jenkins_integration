#!/usr/bin/env bash
set -e

mkdir jenkins-sa && cd jenkins-sa

cat > namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: jenkins
EOF

cat > serviceaccount.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: jenkins
EOF

cat > clusterrole.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins-cluster-role
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
EOF

cat > clusterrolebinding.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-cluster-role-binding
subjects:
  - kind: ServiceAccount
    name: jenkins
    namespace: jenkins
roleRef:
  kind: ClusterRole
  name: jenkins-cluster-role
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f namespace.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f clusterrole.yaml
kubectl apply -f clusterrolebinding.yaml

kubectl create token jenkins -n jenkins > jenkins_token.txt

echo "Jenkins ServiceAccount created in namespace 'jenkins'"
echo "Token saved to jenkins_token.txt"
