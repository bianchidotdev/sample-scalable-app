# Express App

## Running the docker image locally

```
# Create the image
docker build -t michaeldbianchi/express-app .

# Run the image
docker run -p 8080:3000 -d michaeldbianchi/express-app
```

## Architecture

### Terraform
- VPC
  - Subnets (public and private)
  - Route Tables
  - Internet Gateway
  - NAT Gateway
- EKS Cluster
  - IAM Role
- Managed Node Group
  - Security Groups
  - CNI Policy
  - IAM Role
- Cluster Autoscaler Role

### Helm

Imperatively applied, but idempotent
- Cluster Autoscaler
- Prometheus
- Grafana

### Kubernetes Manifests

- Express App
  - Deployment
  - Service
  - Horizontal Pod Autoscaler
  - Ingress resource (for NGINX)
- NGINX
  - NGINX Ingress Controller with NLB automatically created
- Kubernetes Dashboard (for quick overview of cluster)
- Metrics Server (to provide pod and node infra metrics)

---


### Major Components/Decisions

#### Ingress Controller

Using NGINX ingress controller to meet simple routing needs. I attempted to use Contour, which has an envoy proxy service, but it wasn't working.

Using an ingress controller to limit the # of required Load Balancers for the cluster, and also for providing blue-green deployment without DNS cutovers.

A more powerful ingress controller could also provide metrics, tracing, and support for canary style deployments

#### NLB in front of NGINX Ingress Controller

ALB worked just fine in front of the app, but not so much in front of NGINX for some reason. 

Ideally we would use an ALB either directly created by the services in the EKS cluster, or in front of the NLBs created by the cluster in order to provide a WAF.

#### Managed Node Groups

Because why worry about patching servers for no reason. In all reality, I'd use managed node groups unless there was a really compelling reason to use a custom AMI.

#### **eksctl, kubectl, and helm

In the scope of this exercise, I used a variety of eksctl commands, remote helm charts, and declarative manifests in this repo to set up this cluster.

In a real production cluster, I would want everything to be declaratively provisioned.

I configured the deploy such that even though there are imperative commands, the deploy script is idempotent

#### GitHub Actions

Used as both CI and CD currently, to test/lint the codebase, build and push the docker image, and deploy all the TF and K8s resources

All of this is fairly fragile currently and would benefit from a more robust CD solution.


### Optimizations for another time
- Dynamic image tagging - There are rollback challenges when you use a static image tag for deployment
- HTTPS
- Separate repos for Networking (VPC/subnet/NAT), EKS Cluster, and application
- ALB in front of EKS cluster (either through)
- Log forwarding to some log aggregator/indexer
- Ideally in production, we would have access to resources like Prometheus, Grafana, K8s dashboard through an internal ingress controller accessible only via VPN
- Additional observability of networking into applications, providing metrics such as response time, and tracing of each request (solvable using Envoy Sidecars)
- Some namespacing of applications to map to domains/teams
- Argo CD (or other) for more k8s-native application of manifests
- Terraform environments with tfvar files for overrides (potentially used for multi-region as well)
- Make the image smaller - likely needs alpine plus multi-stage build


## Deploying

### Infra/Cluster

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
1. Install helm charts for Cluster Autoscaler, Prometheus, and Grafana  (formerly ALB Controller)
1. Apply all k8s manifests

Extra:

Right now manually import k8s grafana dashboard. Should be possible from configMap with a little bit of work

Click import, enter 3119 for cluster monitoring and 6417 for pod monitoring

### Application

Either update the code and push to GitHub, which triggers a deploy action or run the deploy app script

```sh
# expects docker creds, correctly configured kubectl (usually set up during setup-cluster.sh script)
./bin/deploy-app.sh express-app
```

### Blue-Green Deploy

Update app code as needed, and deploy the code using the following:

```sh
./bin/deploy-app.sh express-app-blue
```

Update `iac/manifests/express-app-ingress.yaml` to point to the `express-app-blue` service and run:

```sh
kubectl apply -f iac/manifests/express-app-ingress.yaml
```

To revert, modify the ingress yaml to point back at `express-app` and re apply the manifest

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

## Autoscaling

Both the express app pods and the cluster autoscales horizontally.

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
