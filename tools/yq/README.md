# yq

## Installation
```bash
wget --no-verbose https://github.com/mikefarah/yq/releases/download/v4.34.2/yq_linux_amd64.tar.gz -O - | tar xz && sudo mv yq_linux_amd64 /usr/bin/yq
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

```bash
yq eval '.data."config.conf" = (.data."config.conf" | sub("mode: \".*\"", "mode: \"ipvs\""))' -i configmap.yaml
```
