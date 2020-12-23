#!/usr/bin/env bash

set -e
if aws sts get-caller-identity; then
  echo "Authenticated for AWS account"
else
  echo "Failed to authenticate - try running `aws sts get-caller-identity`"
fi

export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq -r .Account)

cd iac/
# terraform steps
terraform version
terraform init
terraform apply -auto-approve

#
aws eks --region $(terraform output region) update-kubeconfig --name $(terraform output cluster_id)

# namespaces are needed for helm charts which should be applied before k8s manifests
kubectl apply -f manifests/namespaces.yaml

export CLUSTER_NAME=$(terraform output -json | jq -r .cluster_id.value)

eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve

# Set up necessary values files in needed
cat << EOF > charts/cluster-autoscaler-values.yaml
awsRegion: $AWS_REGION

rbac:
  create: true
  serviceAccount:
    # This value should match local.k8s_service_account_name in locals.tf
    name: cluster-autoscaler-aws-cluster-autoscaler-chart
    annotations:
      # This value should match the ARN of the role created by module.iam_assumable_role_admin in irsa.tf
      eks.amazonaws.com/role-arn: "arn:aws:iam::${AWS_ACCOUNT_ID}:role/cluster-autoscaler"

autoDiscovery:
  clusterName: ${CLUSTER_NAME}
  enabled: true
EOF

cat << EOF > charts/grafana-values.yaml
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.prometheus.svc.cluster.local
      access: proxy
      isDefault: true
EOF

# add autoscaler chart repo
helm repo add autoscaler https://kubernetes.github.io/autoscaler
# add prometheus chart repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# add grafana chart repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add eks https://aws.github.io/eks-charts
# update chart repos
helm repo update

# install autoscaler
helm upgrade -i cluster-autoscaler --namespace kube-system autoscaler/cluster-autoscaler-chart --values=charts/cluster-autoscaler-values.yaml

# install prometheus server
helm upgrade -i prometheus prometheus-community/prometheus \
    --namespace prometheus \
    --set alertmanager.persistentVolume.storageClass="gp2",server.persistentVolume.storageClass="gp2"

# install grafana (conditionally so as to not clobber admin secret)
if bash -c 'helm list -A | grep grafana'; then
  echo "Grafana is already installed"
else
  helm upgrade -i grafana grafana/grafana \
      --namespace grafana \
      --set persistence.storageClassName="gp2" \
      --set persistence.enabled=true \
      --values charts/grafana-values.yaml
fi

# Disabled unless needed in the future
# eksctl create iamserviceaccount \
#   --cluster $CLUSTER_NAME \
#   --namespace kube-system \
#   --name aws-load-balancer-controller \
#   --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
#   --override-existing-serviceaccounts \
#   --approve

# kubectl apply -f manifests/alb-controller/

# export LBC_VERSION="v2.0.0"

# export VPC_ID=$(aws eks describe-cluster \
#                 --name ${CLUSTER_NAME} \
#                 --query "cluster.resourcesVpcConfig.vpcId" \
#                 --output text)

# helm upgrade -i aws-load-balancer-controller \
#     eks/aws-load-balancer-controller \
#     -n kube-system \
#     --set clusterName=${CLUSTER_NAME} \
#     --set serviceAccount.create=false \
#     --set serviceAccount.name=aws-load-balancer-controller \
#     --set image.tag="${LBC_VERSION}" \
#     --set region=${AWS_REGION} \
#     --set vpcId=${VPC_ID}

kubectl apply -Rf manifests
