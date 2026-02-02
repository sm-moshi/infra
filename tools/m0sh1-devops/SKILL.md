---
name: m0sh1-devops
description: >
  Use for DevOps work in m0sh1.cc homelab repos (infra and helm-charts), covering
  GitOps/ArgoCD rules, Helm wrapper charts, Terraform lab workflow, Ansible Vault
  boundaries, and supply-chain checks. Includes repo-specific guard/scaffold tools.
---

# m0sh1 DevOps

Repo-specific DevOps guidance and tools for the m0sh1.cc homelab.

Renovate posture: argocd manager enabled with `/argocd/.+\.yaml$/` patterns, pre-commit manager enabled with `:enablePreCommit` preset. Expect dependency PRs for ArgoCD Applications and pre-commit hooks.

## Integration with Custom Agent

This skill directory supports the **@m0sh1-devops** custom agent, which:

- Enforces all rules defined in this skill automatically
- Uses guard tools (gitops-guard, helm-scaffold, terraform-lab-guard, supply_chain_guard.py) as part of workflows
- Integrates Memory Bank for infrastructure decision logging
- Provides 12 specialized toolsets for GitOps workflows
- Accesses kubectl, Ansible, Terraform, and ArgoCD/Helm documentation

**Agent files:**

- Definition: `tools/m0sh1-devops/m0sh1-devops.agent.md`

**To use:** Type `@m0sh1-devops` in Copilot chat when working with infrastructure.

## Quick Start

```bash
# Validate GitOps hygiene in infra repo
tools/m0sh1-devops/scripts/gitops-guard/gitops-guard -repo .

# Scaffold a wrapper chart + ArgoCD Application
tools/m0sh1-devops/scripts/helm-scaffold/helm-scaffold \
  -repo . \
  -scope user \
  -name example-app \
  -argocd

# Validate Terraform lab conventions
tools/m0sh1-devops/scripts/terraform-lab-guard/terraform-lab-guard -repo .

# Check Ansible playbook idempotency
tools/m0sh1-devops/scripts/check-idempotency/check-idempotency ansible/playbooks/*.yaml

# Check for sensitive files
tools/ci/sensitive-files-guard

# Supply-chain checks (Python only - complex YAML parsing)
python tools/m0sh1-devops/scripts/supply_chain_guard.py --repo .
```

## What This Skill Enforces

- **GitOps only**: No imperative kubectl/helm changes outside bootstrap recovery.
- **Wrapper charts**: Apps go under `apps/cluster` or `apps/user` (wrapper charts).
- **Secrets**: Ansible Vault for host/infra secrets; SealedSecrets for k8s.
- **Terraform**: Only `terraform/envs/lab` is valid; providers/backends live there.
- **Supply chain**: Prefer digests; document tag usage in `docs/history.md`.

## Use These Focused Skills When Needed

- Ansible workflows: `/Users/smeya/.codex/skills/ansible-homelab/SKILL.md`
- Ansible secrets: `/Users/smeya/.codex/skills/ansible-secrets/SKILL.md`

## References (Open When Needed)

- `references/gitops-argocd.md`
- `references/helm-wrappers.md` (includes helm-scaffold usage)
- `references/terraform-lab.md`
- `references/supply-chain.md` (includes supply_chain_guard.py YAML parser details)
