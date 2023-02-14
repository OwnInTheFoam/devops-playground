# Mailu
A full-featured mail server as a set of Docker images. The project aims at providing an easy setup and maintainance, full-featured mail server while not shipping proprietary software nor unrelated features often found in popular groupware.

## Resources
- [Github](https://github.com/Mailu/Mailu)
- [Doucmentation](https://mailu.io/1.7/kubernetes/mailu/index.html)
- [Docker hub](https://hub.docker.com/u/mailu)
- [Helm Chart](https://github.com/Mailu/helm-charts/blob/master/mailu/README.md)
- [Setup Wizard](setup.mailu.io)
- [Guide](https://just-4.fun/blog/howto/oc-k8s-mailu/)
- [LinuxBabe](https://www.linuxbabe.com/mail-server/ubuntu-22-04-iredmail-email-server)

Fail2Ban needs to modify the host’s IP tables in order to ban the addresses. We consider such a program should be run on the host system and not inside a container.

Your host must not listen on ports 25, 80, 110, 143, 443, 465, 587, 993 or 995 as these are used by Mailu services.

## Requirements
- Docker
- DNSSEC compatible resolver
- Traffic ingress controller
- A node which has a public reachable IP
- Hosting service that allows inbound and outbound traffic on port 25
- Helm 3

```bash
mkdir -p /${HOME}/mailu
```

## Installtion
- docker-compose
  ```bash
  setup.mailu.io
  docker-compose -p mailu up -d
  docker-compose -p mailu exec admin flask mailu admin postmaster example.com PASSWORD
  ```
- Helm chart

1. Add helm repo

```bash
helm repo add mailu https://mailu.github.io/helm-charts/
helm repo update
```

2. Setup values

```bash
helm search repo mailu/mailu --versions
helm show values mailu/mailu --version 0.3.3 > /${HOME}/mailu/values.yaml
yq -i '.clusterDomain="example.com"' /${HOME}/mailu/values.yaml
yq -i '.domain="example.com"' /${HOME}/mailu/values.yaml
yq -i '.mailuVersion="1.9.45"' /${HOME}/mailu/values.yaml
yq -i '.hostnames[0]="mail.example.com"' /${HOME}/mailu/values.yaml
yq -i '.secretKey="12345test"' /${HOME}/mailu/values.yaml
yq -i '.persistence.size="20Gi"' /${HOME}/mailu/values.yaml
#yq -i '.ingress.annotations="kubernetes.io/ingress.class: traefik-external"' /${HOME}/mailu/values.yaml
yq -i '.initialAccount.domain="example.com"' /${HOME}/mailu/values.yaml
yq -i '.initialAccount.password="12345test"' /${HOME}/mailu/values.yaml
yq -i '.initialAccount.username="postmaster"' /${HOME}/mailu/values.yaml
yq -i '.front.hostPort.enabled="false"' /${HOME}/mailu/values.yaml
yq -i '.front.externalService.enabled="true"' /${HOME}/mailu/values.yaml
yq -i '.front.externalService.type="LoadBalancer"' /${HOME}/mailu/values.yaml
```

Running on bare metal with k3s and klipper-lb:
If you run on bare metal with k3s (e.g by using k3os), you can use the build-in load balancer klipper-lb. To expose mailu via loadBalancer, set:
```bash
front.hostPort.enabled: false
front.externalService.enabled: true
front.externalService.type: LoadBalancer
front.externalService.externalTrafficPolicy: Local
```

The SECRET_KEY must be changed for every setup and set to a 16 bytes randomly generated value.

Using [traefik](https://mailu.io/1.9/reverse.html#traefik-as-reverse-proxy) solely for routing has limitations for imap and smtp, therefore recommended to run nginx controller along side just for mailu.

3. Deploy chart

```bash
helm install mailu mailu/mailu --version 0.3.3 --values /${HOME}/mailu/values.yaml -n mailu-mailserver --create-namespace
kubectl get namespaces
kubectl get all -n mailu-mailserver
```

## Configuration

### Traefik
To access the services traefik needs to route to them.

```bash
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: mailu
  namespace: mailu-mailserver
  annotations:
    kubernetes.io/ingress.class: traefik-external
    #traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    #traefik.ingress.kubernetes.io/router.tls: "true"
    #traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt-dns
    #traefik.ingress.kubernetes.io/router.rule: "Host(`mail.example.com`)"
    #traefik.ingress.kubernetes.io/service-weights: 'web:100,web-mail:0'
spec:
  entryPoints:
    - web
    - websecure
  routes:
    - match: Host(`mail.example.com`)
      kind: Rule
      services:
      - name: mailu-admin
        port: 80
      - name: mailu-postfix
        port: 25
      - name: mailu-postfix
        port: 465
      - name: mailu-postfix
        port: 587
      - name: mailu-dovecot
        port: 143
      - name: mailu-dovecot
        port: 110
      - name: mailu-dovecot
        port: 993
      - name: mailu-dovecot
        port: 995
  tls:
    secretName: production-tls
```

### Bare metal external

Router port forwarding

```bash
995:32512/TCP,993:32106/TCP,25:31485/TCP,465:32430/TCP,587:30034/TCP
```

## [DNS](https://mailu.io/1.9/dns.html#dns-setup)
DMARC and SPF/DKIM keys

## Test
- Try to send an email to an external service
- On the external service, verify that DKIM and SPF are listed as passing
- Try to receive an email from an external service
- Check the logs (docker-compose logs -f servicenamehere) to look for warnings or errors
- Use an open relay checker like mxtoolbox to ensure you’re not contributing to the spam problem on the internet.
- If using DMARC, be sure to check the reports you get to verify that legitimate email is getting through and forgeries are being properly blocked.

Mail is reachable at `mail.example.com`
Admin panel is reachable at `mail.example.com/admin` with the postmaster username and password.

## Uninstall
```bash
helm uninstall mailu --namespace=mailu-mailserver
helm repo delete mailu
kubectl delete namespace mailu-mailserver
```

## Maintenance checks
It is very important that you check your setup for open relay at least:

after installation
at any time you change network settings or load balancer configuration
The check is quite simple:

watch the logs for the "mailu-front" POD
browse to an open relay checker like https://mxtoolbox.com/diagnostic.aspx
enter the hostname or IP address of your mail server and start the test

## FluxCD
See [k8s-scripts](https://github.com/tigase/k8s-scripts)

### Installation
Create the helm source
```bash
flux create source helm mailu \
 --url=https://mailu.github.io/helm-charts/ \
 --interval=2h \
 --export > "/${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/common/sources/mailu.yaml"
```
Update the kustomize and reconcile
```bash
cd /${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace='flux-system' --autodetect --recursive

cd /${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops
git add -A
git commit -am 'mailu deployment'
git push
flux reconcile source git flux-system
```
Create the helm release from source
```bash
cd /${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/common/sources
rm -f kustomization.yaml
kustomize create --autodetect --recursive
mkdir -p '/${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/apps/mailu-prod'
mkdir -p '/${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/apps/mailu-prod/mailu'

flux create helmrelease mailu \
 --interval=2h \
 --release-name=mailu \
 --source=HelmRepository/mailu \
 --chart-version=0.3.3 \
 --chart=mailu \
 --namespace=mailu-prod \
 --target-namespace=mailu-prod \
 --create-target-namespace \
 --export > /${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/apps/mailu-prod/mailu/mailu.yaml
```
Recreate kustomize
```bash
cd /${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitopsinfra/apps/mailu-prod/mailu
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd /${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/apps/mailu-prod
rm -f kustomization.yaml
kustomize create --autodetect --recursive --namespace='mailu-prod'

cd /${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/apps
rm -f kustomization.yaml
kustomize create --autodetect --recursive
```
Update the manifests
```bash
yq e -i '.spec.chart.spec.sourceRef.namespace = flux-system' /${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/apps/mailu-prod/mailu/mailu.yaml
yq e -i '.spec.timeout = "20m"' '/${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/apps/mailu-prod/mailu/mailu.yaml'
yq e -i '.spec.install.timeout = "20m"' '/${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/apps/mailu-prod/mailu/mailu.yaml'

cat '/${HOME}/tigase/kubernetes-admin@kubernetes/envs/mailu-values.yaml' >> '/${HOME}/tigase/kubernetes-admin@kubernetes/projects/gitops/infra/apps/mailu-prod/mailu/mailu.yaml'
    subnet: 10.244.0.0/16
    secretKey: "redacted"
    domain: "example.com"
    hostnames:
      - "mail.example.com"
    initialAccount:
      username: "postmaster"
      domain: "example.com"
      password: "yourPassword"
```
Update repository and reconcile
```bash
git add -A
git commit -am 'mailu deployment'
git push

flux reconcile source git flux-system
flux get all -A | grep -q Unknown
```

**Check Installation**
```bash
kubectl get namespaces
flux get hr -A
kubectl get all -n mailu-prod
```

### DNS
For webUI, add a DNS entry to point `example.com` to your ingress-nginx LoadBalancer (`192.168.0.240`).
For mail, add a DNS entry to point `mail.example.com` to your external IP service (`192.168.0.241`).

| DNS Entry | Value |
| --------- | ----- |
| Domain name | example.com |
| DNS MX entry | example.com. 600 IN MX 10 mail.example.com. |
| DNS SPF entries | example.com. 600 IN TXT “v=spf1 mx a:mail.example.com ~all” |
| DNS DKIM entry | _This can be set after successful Mailu installation_ |
| DNS DMARC entry | _dmarc.example.com. 600 IN TXT “v=DMARC1; p=reject; adkim=s; aspf=s”
| | example.com._report._dmarc.example.com. 600 IN TXT “v=DMARC1” |
| DNS RFC6186 entries | _submission._tcp.example.com. 600 IN SRV 1 1 587 mail.example.com. |
| | _imap._tcp.example.com. 600 IN SRV 1 1 143 mail.example.com. |
| | _pop3._tcp.example.com. 600 IN SRV 1 1 110 mail.example.com. |
| | _imaps._tcp.example.com. 600 IN SRV 1 1 993 mail.example.com. |
| | _pop3s._tcp.example.com. 600 IN SRV 1 1 995 mail.example.com. |

Test your email sending score
`https://www.mail-tester.com`

### Uninstallation
```bash
rm -rf infra/apps/mailu-prod
cd infra/apps/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

rm -f infra/common/sources/mailu.yaml
cd infra/common/sources
rm -f kustomization.yaml
kustomize create --autodetect --recursive

git add -A
git commit -am 'Removing mailu deployment'
git push
flux reconcile source git flux-system
```
