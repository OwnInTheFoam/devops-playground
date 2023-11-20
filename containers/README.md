# Containers

## Requirements
- cluster with kubectl
- docker cli ($ curl -sSL https://get.docker.com | sh -s -- --version <version>)

## Deploy docker container to containerd

### Create dockerfile

### Upload to docker registry

### Pull images

Log in to your Docker Hub account using the docker command-line tool:
```bash
docker login
```
Pull the image from Docker Hub to your local machine:
```bash
docker pull <image>
```
Alternative use `kubectl` to retrieve the image. A deployment will be created without any pods.
```bash
kubectl run <deployment-name> --image=<image> --restart=Never
docker
```

### Create deployment manifest

Create a deployment configuration file (YAML) and then applying it to the cluster.
```
kubectl apply -f <deployment-configuration-file.yaml>
kubectl get deployments
```

## Testing

### Locally on docker desktop
Create Dockerfile.dev in client folder.
```yaml
FROM node:14.14.0-alpline
WORKDIR /app
COPY ./package.json ./
RUN npm i
COPY . .
CMD ["npm", "run", "start"]
```

Test your docker file and provide a image tag
```bash
docker build -f Dockerfile.dev -t drdre08/multi-client
```

Run your docker image
```bash
docker run -it -p 4002:3000 drdre08/multi-client
```

Open browser
```bash
localhost:4002
```

Create Dockerfile.dev in server folder
```yaml
FROM node:14.14.0-alpline
WORKDIR /app
COPY ./package.json ./
RUN npm i
COPY . .
CMD ["npm", "run", "dev"]
```

Test your docker file and provide a image tag
```bash
docker build -f Dockerfile.dev -t drdre08/multi-server .
```

Run your docker image
```bash
docker run -it -p 4003:5000 drdre08/multi-client
```

Open browser
```bash
localhost:4003
```

Create docker compose to run everything together in local docker desktop
```yaml
version: "3"
services:
  postgres:
    image: "postgres:latest"
    environment:
      - POSTGRES_PASSWORD=postgres_password
  nginx:
    depends_on:
      - api
      - client
    restart: always
    build:
      dockerfile: Dockerfile.dev
      context: ./nginx
    ports:
      - "3050:80"
  api:
    build:
      dockerfile: Dockerfile.dev
      context: "./server"
    volumes:
      - /app/node_modules
      - ./server:/app
    environment:
      - PGUSER=postgres
      - PGHOST=postgres
      - PGDATABASE=postgres
      - PGPASSWORD=postgres_password
      - PGPORT=5432
  client:
    stdin_open: true
    environment:
      - CHOKIDAR_USEPOLLING=true
    build:
      dockerfile: Dockerfile.dev
      context: ./client
    volumes:
      - /app/node_modules
      - ./client:/app
```

Use nginx has a ingress. Create `default.conf` in nginx folder
```
upstream client {
    server client:3000;
}

upstream api {
    server api:5000;
}

server {
    listen 80;

    location / {
        proxy_pass http://client;
    }

    location /sockjs-node {
        proxy_pass http://client;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
    }

    location /api {
        rewrite /api/(.*) /$1 break;
        proxy_pass http://api;
    }
}
```

Create `Dockerfile.dev` in nginx folder
```
FROM nginx
COPY ./default.conf /etc/nginx/conf.d/default.conf
```

Test all deployments
```bash
docker compose up --build
localhost:3050
```
