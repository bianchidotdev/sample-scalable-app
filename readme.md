## Running the docker image

```
# Create the image
docker build -t michaeldbianchi/express-app .

# Run the image
docker run -p 8080:3000 -d michaeldbianchi/express-app
```

## Deploying

Set up aws credentials

```sh
export AWS_ACCESS_KEY_ID=<access_key_id>
export AWS_SECRET_ACCESS_KEY=<secret_access_key>
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq -r .Account)

cd iac/
# terraform steps
terraform init
terraform apply

#
aws eks --region $(terraform output region) update-kubeconfig --name $(terraform output cluster_id)

kubectl apply -f manifests/namespaces.yaml

export CLUSTER_NAME=$(terraform output -json | jq -r .cluster_id.value)

# Set up necessary values files in needed
cat << EOF > charts/cluster-autoscaler-chart-values.yml
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

cat << EOF > charts/grafana-values.yml
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
# update chart repos
helm repo update

# install autoscaler
helm install cluster-autoscaler --namespace kube-system autoscaler/cluster-autoscaler-chart --values=charts/cluster-autoscaler-values.yaml

# install prometheus server
helm install prometheus prometheus-community/prometheus \
    --namespace prometheus \
    --set alertmanager.persistentVolume.storageClass="gp2",server.persistentVolume.storageClass="gp2"

# install grafana
helm install grafana grafana/grafana \
    --namespace grafana \
    --set persistence.storageClassName="gp2" \
    --set persistence.enabled=true \
    --values charts/grafana-values.yaml
    # --set adminPassword='EKS!sAWSome' \


# helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
#   --set clusterName=$CLUSTER_NAME \
#   --set serviceAccount.create=false \
#   --set serviceAccount.name=aws-load-balancer-controller \
#   -n kube-system

kubectl apply -Rf manifests

```

## Monitor the cluster
### Metrics server
Provides access to top commands:
```sh
kubectl top nodes
kubectl top pods
```

### K8s Dashboard

Retrieve a token declared as a secret:
```sh
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}')
```

Proxy the server and open the dashboard
```sh
kubectl proxy

open http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/overview?namespace=default
# Paste the token into the dashboard
```

### Prometheus

```sh
kubectl --namespace=prometheus port-forward deploy/prometheus-server 9090
open http://localhost:9090
```

### Grafana
Get password
```sh
export GRAFANA_PASSWORD=$(kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo)
```

Port forward and open the dashboard
```sh
port-forward -n grafana deploy/grafana 8080:3000
open 
```

## Test Autoscaling
### Cluster Autoscaling
Just scale up the deployment count. The cpu requests for each pod are way too high and will trigger cluster autoscaling prematurely for show

### Horizontal Pod Autoscaling
```
kubectl run -it load-generator --image=busybox -- /bin/sh -c 'while true; do wget -q -O - http://express-app/expensive; done'
```


## TODO for MVP
[ ] stand up eks cluster in reproducable way
[ ] Set up ingress for eks
[ ] Set up auto deploy of terraform and k8s manifests

## Optimizations for another time
- IRSA
- Argo CD for more k8s-native application of manifests
- Terraform environments with tfvar files for overrides
- Make the image smaller - likely needs alpine plus multi-stage build