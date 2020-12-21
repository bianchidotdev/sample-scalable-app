locals {
  cluster_name                  = "express-eks-${random_string.suffix.result}"
  k8s_service_account_namespace = "kube-system"
  k8s_service_account_name      = "cluster-autoscaler-aws-cluster-autoscaler-chart"
}