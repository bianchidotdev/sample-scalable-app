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
```

Run `./bin/check-deps.sh && ./bin/setup-cluster.sh`

Steps in script:
1. Run Terraform
1. Configure kubectl
1. Apply namespaces (done early so helm charts can be applied into them)
1. Enable IRSA (required for cluster autoscaler)
1. Set up necessary values files needed for helm charts (interpolates current AWS Account ID and Cluster Name)
1. Install helm charts for Cluster Autoscaler, Prometheus, Grafana, and ALB Controller
1. Apply all k8s manifests

Extra:

Right now manually import k8s grafana dashboard. Should be possible from configMap
Click import, enter 3119 for cluster monitoring and 6417 for pod monitoring


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
kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

Port forward and open the dashboard
```sh
kubectl port-forward -n grafana deploy/grafana 9091:3000
open http://localhost:9091
```

Import necessary dashboards (3119 - cluster, 6417 - pods)

## Test Autoscaling
### Cluster Autoscaling
Either remove the autoscaler and scale the deployment, edit it to have a minimum of 10 pods, or run through the load generation from the horizontal pod autoscaling section below
```sh
# Option 1:
kubectl delete -f manifests/express-app-autoscaler.yaml
kubectl scale deploy/express-app --replicas=20

# Option 2:
kubectl edit hpa express-app # and change min replicas to 20
```

The cpu requests for each pod are artificially too high and will trigger cluster autoscaling prematurely for show

### Horizontal Pod Autoscaling
```
kubectl run -it load-generator --image=busybox -- /bin/sh -c 'while true; do wget -q -O - http://express-app/expensive; done'

# Review autoscaler with the following
kubectl get hpa express-app -w
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