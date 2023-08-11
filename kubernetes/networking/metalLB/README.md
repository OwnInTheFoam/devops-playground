# MetalLB
MetalLB is a load balancer for kubernetes.

### Helpful resources
- [Just me and OpenSource](https://github.com/justmeandopensource/kubernetes)
- [MetaLB via Flux with Helm](https://geek-cookbook.funkypenguin.co.nz/kubernetes/loadbalancer/metallb/)

#### [Requirements](https://metallb.universe.tf/#requirements)
- Kubernetes v1.13.0+ cluster without a network load balancer
- Cluster with a [network configuration](https://metallb.universe.tf/installation/network-addons/) supported by metalLB
- Range of spare IPv4 for metalLB to distribute
- Port 7946 TCP & UDP open between nodes when using layer 2 operator.

#### [Installation](https://metallb.universe.tf/installation/)
- [Manifest](https://metallb.universe.tf/installation/#installation-by-manifest)
- [Kustomize](https://metallb.universe.tf/installation/#installation-with-kustomize)
- [Helm](https://metallb.universe.tf/installation/#installation-with-helm)

For this tutorial we will install [MetalLB v0.13.3](https://metallb.universe.tf/release-notes/#version-0-13-3) via a manifest file.

#### Steps

1. **Ensure cluster running supported K8s version**

    ```bash
    kubectl get nodes
    ```

2. **Editing kube-proxy config**
    `kubectl edit configmap -n kube-system kube-proxy`
    ```bash
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration
    mode: "ipvs"
    ipvs:
      strictARP: true
    ```
    Edit with scripting:
    ```bash
    kubectl get configmap kube-proxy -n kube-system -o yaml
    sed -e "s/strictARP: false/strictARP: true/"
    kubectl apply -f - -n kube-system
    ```

2. **Apply the manifest**

    ```
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml
    kubectl get namespace
    kubectl -n metallb-system get all
    ```
    Should have;
    - Controller pod.
    - Speaker daemonset and pod that is deployed to all nodes within the cluster.
    - Service account for the controller and speaker.

3. **MetalLB [configuration](https://metallb.universe.tf/configuration/)**

    Previously metalLB used config maps for configuration. However later version of metalLB now use IPAddressPool and either L2Advertisement or BGPAdvertisement. For this tutorial we will use L2Advertisement.

    Apply the IPAddressPool
    ```
    cat >>/root/IPAddressPool.yaml<<EOF
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: first-pool
      namespace: metallb-system
    spec:
      addresses:
      - 192.168.0.240-192.168.0.250
    EOF
    kubectl apply -f IPAddressPool.yaml
    kubectl get ipaddresspools.metallb.io -A
    kubectl describe ipaddresspools.metallb.io "first-pool" -n metallb-system
    ```

    Apply the L2Advertisement
    ```
    cat >>/root/L2Advertisement.yaml<<EOF
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: example
      namespace: metallb-system
    spec:
      ipAddressPools:
      - first-pool
    EOF
    kubectl apply -f L2Advertisement.yaml
    kubectl get L2Advertisements.metallb.io -A
    kubectl describe L2Advertisements.metallb.io example -n metallb-system
    ```

    Ensure all speaker pods are running without the status of configuration error.
    ```
    kubectl -n metallb-system get all
    ```

4. **Test access to deploment**

    Create a nginx pod
    ```
    kubectl create deploy nginx --image nginx
    kubectl get all
    ```
    Expose the nginx deployment via service
    ```
    kubectl expose deploy nginx --port 80 --type LoadBalancer
    kubectl get all
    ```
    Verify nginx pod is accessable from the external ip
    ```
    curl 192.168.0.240

5. **Public access to deployment**

    _May need to deploy ingress controller_
    Port forward HTTP port 80 traffic to the nginx external IP address through your router. Then test the connection:
    ```
    curl PUBLIC-IP
    ```
    You may setup a DNS A record so a domain resolves to the external ip address of your deployment. Then test the connection:
    ```
    curl http://domain.me
    ```
    
6. **Delete nginx deployment**

  ```
  sudo kubectl delete deployment nginx
  ```

