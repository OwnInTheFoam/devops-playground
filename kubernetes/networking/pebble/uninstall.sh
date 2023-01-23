#!/bin/bash

# Remove the websecure ingres route
kubectl delete -f tls-ingress-route.yaml

# Remove tls values from traefik values file
sed -i 's/ additionalArguments:/ additionalArguments: []/g' /root/traefik-values.yaml
sed -i 's/ volumes:/ volumes: []/g' /root/traefik-values.yaml
sed -i 's/ env:/ env: []/g' /root/traefik-values.yaml

# Apply the reverted values
helm upgrade --install traefik traefik/traefik --version 20.8.0 --values /root/traefik-values.yaml -n traefik

# Remove pebble values file
rm -r /root/pebble-values.yaml

# Remove pebble server
helm uninstall --purge pebble -n traefik

