---
name: m0sh1-devops
description: >
  Use for DevOps work in m0sh1.cc homelab repos (infra and helm-charts), covering
  GitOps/ArgoCD rules, Helm wrapper charts, Terraform lab workflow, Ansible Vault
  boundaries, supply-chain checks, observability rollout, and DHI image migrations.
---

# m0sh1 DevOps

Repo-specific DevOps guidance and tooling for the m0sh1.cc homelab./

## Authoritative Rules

- `AGENTS.md` (hard rules)
- `docs/warp.md` (operational guide)
- `docs/layout.md` (canonical structure)

## Agent Definition

- `tools/m0sh1-devops/agents/m0sh1-devops.agent.md`

## Install (Symlink to Codex Skills)

```bash
ln -sfn /Users/smeya/git/m0sh1.cc/infra/tools/m0sh1-devops \
  /Users/smeya/.codex/skills/m0sh1-devops
```

## Quick Start

```bash
# Policy + safety checks
mise run policy

# Helm + Kubernetes validation
mise run k8s-lint

# Sensitive files + path drift
mise run sensitive-files
mise run path-drift

# Terraform (validate only)
mise run terraform-validate

# Ansible idempotency
mise run ansible-idempotency

# Guard scripts (direct)
tools/m0sh1-devops/scripts/gitops-guard/gitops-guard -repo .
tools/m0sh1-devops/scripts/helm-scaffold/helm-scaffold -repo . -scope user -name example-app -argocd
tools/m0sh1-devops/scripts/terraform-lab-guard/terraform-lab-guard -repo .
tools/m0sh1-devops/scripts/check-idempotency/check-idempotency ansible/playbooks/*.yaml

# Supply-chain checks (currently Python; Go port planned)
python tools/m0sh1-devops/scripts/supply_chain_guard.py --repo .
```

## What This Skill Enforces

- **GitOps only**: No imperative kubectl/helm changes outside bootstrap recovery.
- **Wrapper charts**: Apps go under `apps/cluster` or `apps/user` (wrapper charts).
- **Secrets**: Ansible Vault for host/infra secrets; SealedSecrets for k8s.
- **Terraform**: Only `terraform/envs/lab` is valid; providers/backends live there.
- **Supply chain**: Prefer digests; document tag usage in `docs/history.md`.

## Current Focus (Diaries)

- Observability rollout: `docs/diaries/observability-implementation.md`
- cert-manager DHI: `docs/diaries/cert-manager-dhi.md`
- trivy DHI: `docs/diaries/trivy-dhi.md`

## Use These Focused Skills When Needed

- Ansible workflows: `/Users/smeya/.codex/skills/ansible-homelab/SKILL.md`
- Ansible secrets: `/Users/smeya/.codex/skills/ansible-secrets/SKILL.md`

## References (Open When Needed)

- `references/gitops-argocd.md`
- `references/helm-wrappers.md` (includes helm-scaffold usage)
- `references/terraform-lab.md`
- `references/supply-chain.md` (includes supply_chain_guard.py YAML parser details)
