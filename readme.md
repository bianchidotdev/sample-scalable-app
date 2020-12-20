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
kubectl apply -f manifests
```

## TODO for MVP
[ ] stand up eks cluster in reproducable way
[ ] Set up ingress for eks
[ ] Set up auto deploy of terraform and k8s manifests

## Things to reseach
- How much effort is argocd really? Is it worth it?

## Optimizations for another time
- Argo CD for more k8s-native application of manifests
- Terraform environments with tfvar files for overrides
- Make the image smaller - likely needs alpine plus multi-stage build