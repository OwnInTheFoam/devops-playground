# Containers

## Requirements
- cluster with kubectl
- docker cli ($ curl -sSL https://get.docker.com | sh -s -- --version <version>
)

## Deploy docker container to containerd

### Create dockerfile

### Upload to docker registry

### Pull images

Log in to your Docker Hub account using the docker command-line tool:
```
docker login
```
Pull the image from Docker Hub to your local machine:
```
docker pull <image>
```
Alternative use `kubectl` to retrieve the image. A deployment will be created without any pods.
```
kubectl run <deployment-name> --image=<image> --restart=Never
docker
```

### Create deployment manifest

Create a deployment configuration file (YAML) and then applying it to the cluster.
```
kubectl apply -f <deployment-configuration-file.yaml>
kubectl get deployments
```

