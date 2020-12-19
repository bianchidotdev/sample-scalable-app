## Running the docker image

```
# Create the image
docker build -t michaeldbianchi/express-app .

# Run the image
docker run -p 8080:3000 -d michaeldbianchi/express-app
```

## TODO for MVP
- stand up eks cluster in reproducable way


## Things to reseach
- How much effort is argocd really? Is it worth it?

## Optimizations for another time
- Argo CD for more k8s-native application of manifests
- Make the image smaller - likely needs alpine plus multi-stage build