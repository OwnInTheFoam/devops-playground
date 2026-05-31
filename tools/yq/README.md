# yq

## Installation
```bash
# Set your platform variables (adjust as needed)
export VERSION=v4.53.2
export PLATFORM=linux_amd64

# Download compressed binary
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_${PLATFORM}.tar.gz -O - |\
  tar xz && sudo mv yq_${PLATFORM} /usr/local/bin/yq
```

## Usage
```bash
yq -i '.clusterDomain="example.com"' /${HOME}/mailu/values.yaml
yq -i '.hostnames[0]="mail.example.com"' /${HOME}/mailu/values.yaml
yq e -i '.spec.upgrade.remediation.retries = 3' "${CL_DIR}/${NAME}/${NAME}.yaml"
yq -i '.globalArguments[0]="--global.checknewversion=false" | .globalArguments.[] style="double"' /${HOME}/traefik/traefik-values.yaml
yq -i '.globalArguments[1]="--global.sendanonymoususage=false" | .globalArguments.[] style="double"' /${HOME}/traefik/traefik-values.yaml
yq -i '.ingressRoute.dashboard.enabled=false' /${HOME}/traefik/traefik-values.yaml
yq -i '.additionalArguments += "--serversTransport.insecureSkipVerify=true" | .additionalArguments.[] style="double"' /${HOME}/traefik/traefik-values.yaml
yq -i '.additionalArguments += "--log.level=INFO" | .additionalArguments.[] style="double"' /${HOME}/traefik/traefik-values.yaml
yq -i '.ports.web.redirectTo="websecure"' /${HOME}/traefik/traefik-values.yaml
```

Set a variable with double quotes
```bash
yq -i '.prometheus.additionalServiceMonitors[0].name="loki-monitor"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].name style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
```

```bash
yq eval '.data."config.conf" = (.data."config.conf" | sub("mode: \".*\"", "mode: \"ipvs\""))' -i configmap.yaml
```
