# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.4.6 bash
k3d version

# Install docker
#curl -fsSL https://get.docker.com -o get-docker.sh
#sudo sh get-docker.sh
#sudo apt-cache policy docker-ce
#sudo apt-get install docker-ce=17.06.0~ce-0~ubuntu

# Create k3d cluster called workshop with 2 agents
k3d cluster create workshop \
--k3s-arg "--disable=traefik@server:0"  \
--api-port 127.0.0.1:6550 \
-p "80:80@loadbalancer" \
-p "443:443@loadbalancer" \
--agents 2
k3d cluster list
#k3d cluster delete workshop

# Install kubectl 
#curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/v1.25.4/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin
kubectl version

# Install traefik
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm install traefik traefik/traefik --version 20.6.0

