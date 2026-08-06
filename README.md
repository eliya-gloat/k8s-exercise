# k8s-exercise

Helm deployments for platform services. ArgoCD renders each app from this repo; nothing is applied by hand.

## Layout

```
apps/
  <app>/
    Chart.yaml                        depends on devops_infra (helm-chart-exercise)
    templates/                        app-owned objects, including <app>-env-vars
    development/values.yaml           shared by every dev cluster
    development/<cluster>/<namespace>/values.yaml
    production/<cluster>/<namespace>/values.yaml
tools/render.sh
```

An app is deployed to a cluster/namespace **if and only if** its values directory exists.

| Clusters                              |             |
| ------------------------------------- | ----------- |
| `dev-eks-euc1-01`, `dev-eks-apse1-01` | development |
| `prod-eks-euc1-01`                    | production  |

Namespaces named `fe-*` are feature environments.

Most services are **regional**: they run in every region and are reached in-cluster at
`http://<service>.<namespace>.svc.cluster.local`. A few are **global**: they run only in euc1, and other regions
reach them at `https://<host>-euc1.<envType>.internal.example`.

## Values

- **Development** merges two files: `development/values.yaml`, then `development/<cluster>/<namespace>/values.yaml`.
- **Production** uses one file: `production/<cluster>/<namespace>/values.yaml`.
- ArgoCD also sets `global.envType`, `global.region` and `global.clusterName` from the cluster name.

Templates under `apps/<app>/templates/` are shared by every environment the app runs in.

## The base chart

Most apps depend on `devops_infra` from [helm-chart-exercise](https://github.com/eliya-gloat/helm-chart-exercise),
which renders the Deployment, the Service and the `<app>-common-env-vars` ConfigMap. Its README is the
contract for the chart's values and for environment precedence. The version each app gets is whatever its
`Chart.yaml` constraint resolves to at render time.

## Rendering

```
tools/render.sh <app> <cluster> [namespace]
```

Produces exactly what ArgoCD would apply for that app on that cluster, one block per namespace. Requires
`helm` and network access to the chart repository.

To render against an unreleased change to the base chart, point `DEVOPS_INFRA_CHART` at a local checkout:

```
DEVOPS_INFRA_CHART=../helm-chart-exercise/charts/devops_infra tools/render.sh <app> <cluster>
```

Apps whose `devops_infra` constraint does not admit the local chart's version keep the published one, as they
would in ArgoCD.

## CI

`.github/workflows/lint.yml` runs `prettier --check` and `helm lint` on every pull request.
