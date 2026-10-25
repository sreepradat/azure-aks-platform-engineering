# Architecture

## Components

| Component | Purpose |
|---|---|
| Resource group `rg-aksplat-dev` | Holds everything in the dev environment, so it can be inspected and destroyed as one unit |
| Virtual network + `snet-aks` subnet | Network for the cluster nodes |
| AKS cluster | Runs the workload. OIDC issuer and Workload Identity enabled, Azure CNI overlay, Azure network policy, cluster autoscaler (1-2 nodes) |
| Azure Container Registry | Stores images. Admin account disabled; the cluster pulls with its kubelet identity (`AcrPull`) |
| Key Vault | Stores the demo secret. RBAC authorization, no access policies |
| User-assigned managed identity | The identity the pod assumes. Has `Key Vault Secrets User` on the vault only |
| Federated identity credential | Trusts tokens from the AKS OIDC issuer for exactly one service account (`system:serviceaccount:sample-app:sample-app`) |
| Storage account (created by script) | Terraform remote state, with blob versioning |
| Entra app registration (created by script) | Identity used by GitHub Actions through OIDC federation |

## Authentication flows

### GitHub Actions to Azure (OIDC)

```mermaid
sequenceDiagram
    participant W as GitHub Actions job
    participant G as GitHub OIDC provider
    participant E as Microsoft Entra ID
    participant A as Azure (ARM, ACR, AKS)

    W->>G: Request ID token (audience api://AzureADTokenExchange)
    G-->>W: Signed JWT (sub = repo, ref / pull_request / environment)
    W->>E: Exchange JWT using azure/login
    E->>E: Match sub against federated credentials
    E-->>W: Short-lived Azure access token
    W->>A: Call Azure APIs with that token
```

Federated credentials exist for three subjects, so only these contexts can sign in:

| Subject | Used by |
|---|---|
| `repo:<owner>/<repo>:pull_request` | Terraform plan on pull requests |
| `repo:<owner>/<repo>:ref:refs/heads/main` | Plan and image build on `main` |
| `repo:<owner>/<repo>:environment:dev` | Terraform apply, Helm deploy, destroy (these wait for approval) |

### Pod to Key Vault (Workload Identity)

```mermaid
sequenceDiagram
    participant P as Pod (service account sample-app)
    participant K as AKS OIDC issuer
    participant E as Microsoft Entra ID
    participant V as Key Vault

    P->>K: Projected service account token
    P->>E: Exchange token (federated identity credential)
    E-->>P: Access token for the managed identity
    P->>V: Read secret app-message
    V-->>P: Secret value (mounted at /mnt/secrets)
```

The Secrets Store CSI driver performs this exchange when the pod starts and refreshes the secret on rotation.

## Delivery flow

```mermaid
flowchart TD
    pr[Pull request] --> ci[CI: ruff, pytest, terraform validate, helm lint, hadolint, Checkov]
    pr --> plan[Infra: terraform plan on PR]
    ci --> merge[Merge to main]
    plan --> merge
    merge --> apply{Terraform changed?}
    apply -- yes --> approve1[Approval: dev environment]
    approve1 --> tfapply[terraform apply saved plan]
    merge --> build[Build image]
    build --> scan[Trivy scan]
    scan -- fails --> stop([Stop: nothing is pushed])
    scan -- passes --> push[Push image tagged with commit SHA to ACR]
    push --> approve2[Approval: dev environment]
    approve2 --> deploy[helm upgrade --install --atomic]
    deploy -- fails --> rollback([Automatic rollback])
    deploy -- succeeds --> done([Service running])
```

## Reusable workflow contracts

| Workflow | Key inputs | Outputs |
|---|---|---|
| `reusable-docker-build.yml` | `image-name`, `acr-name`, Azure IDs | `image-ref`, `image-repository`, `image-tag` |
| `reusable-helm-deploy.yml` | `environment`, `resource-group`, `cluster-name`, `image-repository`, `image-tag`, `workload-identity-client-id`, `key-vault-name`, Azure IDs | none (writes the endpoint to the run summary) |
| `reusable-terraform.yml` | `working-directory`, `environment`, `apply`, state backend settings, Azure IDs | none (writes the plan to the run summary) |

All environment-specific values are passed as inputs by the caller (`ci.yml`, `cd.yml`, `infra.yml`), which read them from repository variables. Nothing is hardcoded inside the reusable workflows, which is what makes them shareable across repositories.

## Terraform module graph

```mermaid
flowchart LR
    rg[resource group] --> network
    rg --> acr
    rg --> keyvault
    network --> aks
    acr --> aks
    aks -->|oidc_issuer_url| wi[workload-identity]
    keyvault -->|id| wi
```
