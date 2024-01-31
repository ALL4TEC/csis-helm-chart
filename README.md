### Copyright 2024 ALL4TEC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

# CSIS Helm Chart

Helm Chart to deploy CSIS.

## Installation

### Preamble

**Per namespace:**

- Patch default namespace serviceaccount:

```sh
# Must patch existing default serviceaccount in corresponding namespace as we cannot override it through an Helm resource directly
$ kubectl -n <namespace> patch serviceaccount default -p '{"imagePullSecrets": [{"name": "oci-compliant-registry"}]}'
```

### Requirements

**Per cluster:**

- Charts to install:
  - longhorn (through rancher tools)
  - kcert
  - ingress-nginx
  - securecodebox if SCB_SCANNERS not empty

**As helm dependencies are all installed in same namespace, we need to manually install requirements before chart installation.**

#### [Longhorn](https://longhorn.io/docs/latest/)

**Setup an AWS S3 bucket (potentially stored on another cloud provider) as Backup target**

*From file*

```sh
$ echo -n '<your-aws-access-key-id-here>' > AWS_ACCESS_KEY_ID
$ echo -n '<your-aws-secret-access-key-here>' > AWS_SECRET_ACCESS_KEY
$ kubectl create secret generic -n <namespace> <s3-secret-name> \
    --from-file=./AWS_ACCESS_KEY_ID \
    --from-file=./AWS_SECRET_ACCESS_KEY
secret/<s3-secret-name> created
```

*From literal*

```sh
$ kubectl create secret generic -n longhorn-system <s3-secret-name> \
    --from-literal=AWS_ACCESS_KEY_ID=<your-aws-access-key-id> \
    --from-literal=AWS_SECRET_ACCESS_KEY=<your-aws-secret-access-key>
secret/<s3-secret-name> created
```

Backups are managed per cluster through ui, where recurring backup jobs are scheduled too.
If moving instance from cluster to another, pvcs must be restored before deploying chart, and volumes names must be specified corresponding to each service

- PVCs must be annotated to be usable by helm chart release (a patch must have been generated for that by longhorn migration script):

After each pvc restoration:

```sh
$ kubectl -n <namespace> patch pvc <pvc_name> --patch-file patch_pvcs_before_restore.yml
```

- Add/Edit [storageclass](https://stackoverflow.com/questions/62960776/kubectl-command-to-patch-a-specific-attribute-in-kubernetes-storage-class) (non namespacées) longhorn after longhorn installation:

```sh
$ kubectl apply -f storageclass_longhorn.yaml
# If replace needed
$ kubectl replace -f storageclass_longhorn.yaml --force
```

#### [kcert](https://github.com/nabsul/kcert)

**Install**

```sh
helm repo add nabsul https://nabsul.github.io/helm
kubectl create ns kcert
# Test with Let's Encrypt's staging env
helm install kcert nabsul/kcert -n kcert --debug -f kcert_values_staging.yaml
# Switch to Let's Encrypt production env
helm install kcert nabsul/kcert -n kcert --debug -f kcert_values_production.yaml
```

#### [ingress-nginx](https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx)

**ingress-nginx in default namespace**

```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx
```

**Upgrade:**

```sh
helm upgrade ingress-nginx ingress-nginx/ingress-nginx
```

**Update configmap:**

This will update configmap used by ingress-nginx for entire cluster, applying configuration for all resources using ingress-nginx
A more csis specific solution could be to deploy one instance of ingress-nginx per namespace and to specify a dedicated configmap per namespace

```sh
kubectl apply -f ingress-nginx-controller.yaml
```

#### [securecodebox](https://docs.securecodebox.io/docs/getting-started/installation/)

**securecodebox operator in securecodebox-system**

*Only if needed*

```sh
$ helm repo add secureCodeBox https://charts.securecodebox.io
$ kubectl create namespace securecodebox-system
# Create a scb-s3-secret to access s3-securecodebox bucket for external data storage
# Replace *** with appropriate values
$ kubectl -n securecodebox-system create secret generic scb-s3-creds --from-literal=accesskey="******" --from-literal=secretkey="******"
$ helm --namespace securecodebox-system upgrade --install securecodebox-operator secureCodeBox/operator -f scb_operator_values.yaml
# Webhook: Generate an uuid for url
$ SECURE_CODE_BOX_WH_UUID=$(bundle exec rake uuid:gen)
# Webhook: installation: Replace <ROOT_URL> by env var ROOT_URL corresponding to csis root url
$ helm upgrade --install gwh secureCodeBox/generic-webhook -n <namespace> --set webhookUrl="<ROOT_URL>/webhook/securecodebox/<SECURE_CODE_BOX_WH_UUID>"
```

## DNS

**Get external-ip to fill dns entry corresponding to new instance**

```sh
kubectl get ingresses -n <namespace>
# Then look for LoadBalancers ips and create dns records linking:
# ip<->instance domain
# and ip<->pg admin domain
```

## CSIS

### Mandatory values

**Use LMAN UI to easily generate values file**

List of values to fill if new instance, else use the old ones:

```yaml
csis:
  image:
    registryUsername:
    registryPassword:
  initialization:
    userEmail:
    userFullName:
    userPassword:
masterKey:
otpSecretEncryptionKey:
mail:
  emailPassword:
postgres:
  dbPassword:
pgadmin:
  adminPassword:
securecodebox:
  webhook:
    uuid:
```

```bash
# Install from registry :
# - The feature is still experimental, enable it
export HELM_EXPERIMENTAL_OCI=1
# - Login with csis helm chart repository deploy token !
$ helm registry login dhnhft3k.gra7.container-registry.ovh.net -u "${HARBOR_USERNAME}" -p "${HARBOR_PASSWORD}"
# - Pull chart
$ helm chart pull dhnhft3k.gra7.container-registry.ovh.net/csis/csis-helm-chart:<version>
# - Export chart to local directory
$ helm chart export dhnhft3k.gra7.container-registry.ovh.net/csis/csis-helm-chart:<version>
# - Fill mandatory variables in values.yaml then install csis
$ helm install -f <values_filename> <instance_name> csis

## OR ##

# Install from local git repo :
# - Clone distant repository
$ git clone <repo_url>/csis-helm-chart.git
# - Fill mandatory variables in values.yaml then install csis
$ helm install -f <values_filename> <instance_name> csis
```

## Modifying the chart

Increment version in Chart.yaml file. Lint and test on a virgin cluster/environment.

### Lint chart

```bash
helm lint csis -f lint_mandatory_values.yaml

# Result :
==> Linting csis

1 chart(s) linted, 0 chart(s) failed
```

### Test installation without creating objects

```bash
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "oci-compliant-registry"}]}'
helm template <instance_name> csis --dry-run --debug -f <values.yaml> > result_file.txt
```

### Update dependencies

```bash
helm dependency update csis
```

## Cheatsheet

> <https://www.tutorialworks.com/kubernetes/helm-cheatsheet/>
