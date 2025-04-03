# Gitlab CI/CD

## Resources
- [Gitlab pipeline video](https://www.youtube.com/watch?v=W0lnWumzSKw)
- [Gitlab runner](https://www.youtube.com/watch?v=nbEVqNbYvCQ)
- [Gitlab container registry](https://www.youtube.com/watch?v=ZJZGJTM23z0)

## Background

**Continuous Integration**
Build -> Unit Tests -> Merge

**Continuous Delivery**
Build -> Unit Tests -> Merge -> Acceptance Test -> Deploy to Staging -(manually)> Deploy Production

**Continuous Deployment**
Build -> Unit Tests -> Merge -> Acceptance Test -> Deploy to Staging -> Deploy Production

**Gitlab pipeline**
Any commits to the gitlab repository the gitlab runner will start the pipeline specified in the .gitlab-ci.yml file in root directory.

## Pipeline Runner
1. Create a Gitlab account and project
4. In the project select `Add CI/CD` this should allow you to commit a template of `.gitlab-ci.yml`, which is your configuration for building and pushing new releases.
5. Disable shared runners via Settings > CI/CD > Shared runners
5. Deploy a [pipeline runner](https://docs.gitlab.com/runner/install/) to your cluster
  **[Helm](https://docs.gitlab.com/runner/install/kubernetes.html)**
  ```bash
  helm search hub --max-col-width 80 gitlab-runner | grep "/gitlab/gitlab-runner"
  sudo helm repo add gitlab https://charts.gitlab.io
  helm repo update gitlab
  helm show values gitlab/gitlab-runner --version 0.55.0 > ${HOME}/${K8S_CONTEXT}/tmp/gitlabrunner-values.yaml
  ```
  [Configure chart values](https://docs.gitlab.com/runner/install/kubernetes.html#configuring-gitlab-runner-using-the-helm-chart)
7. Enable runner via settings > CI/CD settings > Runners > New project runner
  ```bash
  yq -i '.gitlabUrl=https://gitlab.com' /${HOME}/${K8S_CONTEXT}/tmp/gitlabrunner-values.yaml
  yq -i '.runnerToken="glrt-"' /${HOME}/${K8S_CONTEXT}/tmp/gitlabrunner-values.yaml
  sudo helm install gitlab-runner gitlab/gitlab-runner --version 0.55.0 --values /${HOME}/${K8S_CONTEXT}/tmp/gitlabrunner-values.yaml -n default --create-namespace
  ```

## Container Registry

1. Create a Gitlab account and project
2. Set the project to private via the general project settings
3. Enable container registry via the general project settings
4. Install docker on local computer and enusre you can [authenticate](https://docs.gitlab.com/ee/user/packages/container_registry/authenticate_with_container_registry.html)
  ```bash
  docker login gitlab.com
  docker login gitlab.com -u <username> -p <password/token>
  ```
5. Push images to container registry
  ```bash
  docker build -t registry.gitlab.com/group/project .
  docker push registry.gitlab.com/group/project
  ```
6. Create deploy token `Settings > Repository > Deploy Tokens`  OR personal access token `User avatar > Edit profile > Access tokens > Personal access tokens`
7. Configure [kubernetes](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)/[containerd](https://github.com/containerd/containerd/blob/main/docs/cri/registry.md#configure-registry-credentials) to connect to gitlab container registry
  
  ```bash
  sudo kubectl create secret docker-registry gitlab-registry-secret \
  --docker-server=registry.gitlab.com \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD_OR_TOKEN \
  --docker-email=YOUR_EMAIL
  ```
8. Configure deployments to pull containers from registry with secret

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: my-pod
  spec:
    containers:
    - name: my-container
      image: YOUR_REGISTRY_URL/YOUR_PROJECT/YOUR_IMAGE:TAG
    imagePullSecrets:
    - name: gitlab-registry-secret
  ```

## Adding releases

1. Locally build your Docker images using `docker build` commands.
2. Tag the images using the GitLab Container Registry URL (`registry.gitlab.com/YOUR_PROJECT/YOUR_IMAGE:TAG`)
3. Log in to the GitLab Container Registry using the `docker login` command with your GitLab credentials.
4. Push the images to the registry using `docker push`.

