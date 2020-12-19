## Running the docker image

```
# Create the image
docker build -t michaeldbianchi/scalable-web-app .

# Run the image
docker run -p 8080:3000 -d michaeldbianchi/scalable-web-app
```