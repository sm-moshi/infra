# Helm Charts

This directory contains Helm wrapper charts for application deployments.

## Structure

```
helm/
├── charts/           # Wrapper charts
│   ├── app-name/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   ├── values-prod.yaml
│   │   └── templates/
└── README.md
```

## Prerequisites

- Helm >= 3.0.0
- kubectl configured for target cluster
- Access to Helm chart repositories

## Usage

### Creating a Wrapper Chart

```bash
cd helm
helm create my-app
```

### Adding Dependencies

Edit `Chart.yaml`:

```yaml
apiVersion: v2
name: my-app
version: 0.1.0
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: https://charts.bitnami.com/bitnami
```

Update dependencies:

```bash
helm dependency update my-app/
```

### Installing Charts

```bash
# Install with default values
helm install my-release helm/my-app

# Install with environment-specific values
helm install my-release helm/my-app -f helm/my-app/values-prod.yaml

# Upgrade release
helm upgrade my-release helm/my-app

# Dry run
helm install my-release helm/my-app --dry-run --debug
```

### Linting

```bash
helm lint my-app/
```

### Template Rendering

```bash
helm template my-release my-app/ -f my-app/values-dev.yaml
```

## Best Practices

- Use wrapper charts to customize upstream charts
- Keep values files environment-specific
- **Never commit secrets** - use Sealed Secrets
- Pin chart versions in dependencies
- Use semantic versioning
- Document all values in README
- Test with `helm lint` and `--dry-run`
- Use Helm hooks for lifecycle management
- Implement resource limits and requests

## Chart Structure

```
my-app/
├── Chart.yaml          # Chart metadata
├── values.yaml         # Default values
├── values-dev.yaml     # Development values
├── values-staging.yaml # Staging values
├── values-prod.yaml    # Production values
├── templates/          # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── sealed-secret.yaml
├── charts/             # Dependency charts (generated)
└── README.md           # Chart documentation
```

## Secrets Management

**Use Sealed Secrets for sensitive data**

```yaml
# templates/sealed-secret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: {{ include "my-app.fullname" . }}-secret
spec:
  encryptedData:
    password: AgBy3i4OJSWK+PiTySYZZA...  # Encrypted value
```

Generate sealed secret:

```bash
kubectl create secret generic my-secret \
  --from-literal=password=my-password \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml
```

## Values Files

### values.yaml (defaults)

```yaml
replicaCount: 1

image:
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

### values-prod.yaml (production overrides)

```yaml
replicaCount: 3

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

## Security

- ⚠️ **Never commit** plain text secrets
- Use Sealed Secrets for all sensitive data
- Implement Pod Security Standards
- Set resource limits
- Use non-root users
- Enable network policies
- Scan images for vulnerabilities
- Use read-only root filesystem where possible

## ArgoCD Integration

Charts in this directory can be deployed via ArgoCD:

```yaml
# argocd/applications/my-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
spec:
  source:
    repoURL: https://github.com/sm-moshi/infra
    path: helm/my-app
    helm:
      valueFiles:
        - values-prod.yaml
```

## Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
