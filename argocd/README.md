# ArgoCD Applications

This directory contains ArgoCD Application and AppProject manifests for GitOps continuous delivery.

## Structure

```
argocd/
├── applications/     # Application manifests
├── projects/         # AppProject definitions
└── README.md
```

## Usage

### Creating an Application

Create an Application manifest that points to your Kubernetes manifests:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR-ORG/YOUR-REPO
    targetRevision: main
    path: helm/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Applying Applications

```bash
kubectl apply -f applications/my-app.yaml
```

## Best Practices

- Use AppProjects to organize and restrict applications
- Enable automated sync with prune and self-heal
- Use sync windows for controlled deployments
- Implement RBAC at the AppProject level
- Version control all Application manifests

## Security

- Never commit secrets in Application manifests
- Use Sealed Secrets for sensitive data
- Restrict destination namespaces in AppProjects
- Review sync policies carefully

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Application Specification](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
