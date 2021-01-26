
# jsp-gcm
=======

# deployer

From
[building-deployer-helm.md](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/master/docs/building-deployer-helm.md),
the `chart/` folder is a vendored version of our helm chart (except for the
file `templates/application.yaml` that was added):

```sh
helm repo add jetstack https://charts.jetstack.io
helm dependency build chart/jetstacksecure-mp
```

