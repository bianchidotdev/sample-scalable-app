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

# terraform steps
terraform init
terraform apply

#
aws eks --region $(terraform output region) update-kubeconfig --name $(terraform output cluster_id)

helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  -n kube-system

kubectl apply -Rf manifests

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

## Things to reseach
- How much effort is argocd really? Is it worth it?

## Optimizations for another time
- IRSA
- Argo CD for more k8s-native application of manifests
- Terraform environments with tfvar files for overrides
- Make the image smaller - likely needs alpine plus multi-stage build