# Interview notes for this project

Personal prep notes. Delete this file before publishing if you prefer, or keep it, as it is useful for anyone reading the repo.

**Be accurate about what this is.** This is a personal portfolio project that reproduces the patterns from client work. Say so. Then deploy it at least once yourself, break things on purpose and fix them, so that every answer below comes from experience and not from reading.

## 60-second pitch

"I built an end-to-end platform on Azure. Terraform provisions the network, AKS, a container registry and Key Vault from reusable modules, with remote state in blob storage. GitHub Actions handles delivery through reusable workflows: CI runs lint, tests, Terraform validation and security scans, and CD builds the image, scans it with Trivy, pushes to ACR, and deploys with Helm using atomic releases. Authentication from GitHub to Azure uses OIDC federation, so there are no stored credentials, and the pods read secrets from Key Vault through Workload Identity. Terraform apply and deployments are gated by environment approvals, and there is a destroy workflow to control cost."

## Likely questions

**Why OIDC instead of a service principal secret?**
A secret has to be stored, rotated and can leak. With OIDC, GitHub issues a short-lived token per run and Entra ID checks its claims against federated credentials, which I limited to this repository's pull requests, `main` branch and `dev` environment. There is nothing long-lived to steal.

**Why reusable workflows?**
In client work many repositories needed the same build and deploy logic. Putting it in versioned reusable workflows means a fix or a security change is made once and adopted by callers by bumping a version tag, and caller workflows stay a few lines long. Here they live in the same repo for simplicity, but they take everything as inputs, so they can move to a shared repo unchanged.

**How does the pod get a secret from Key Vault?**
The AKS cluster has an OIDC issuer. A federated identity credential on a user-assigned managed identity trusts tokens for one service account (`system:serviceaccount:sample-app:sample-app`). The pod uses that service account and the label `azure.workload.identity/use: "true"`. The Secrets Store CSI driver exchanges the pod's token for an Entra token and mounts the secret as a file. The identity has `Key Vault Secrets User` on that single vault.

**What happens if the deployment fails?**
`helm upgrade --atomic --wait` waits for the rollout to become ready, and rolls back to the previous release if it does not. Readiness probes prevent traffic going to pods that are not healthy. Images are tagged with the commit SHA so I know exactly what is running.

**How do you protect the pipeline and the supply chain?**
Trivy blocks critical and high vulnerabilities before the image is pushed. The Dockerfile is linted, the container runs as non-root with a read-only filesystem and no capabilities, Terraform is scanned with Checkov, and Dependabot updates actions, Python packages, the base image and providers. Next steps would be image signing with Cosign and an SBOM.

**How do you manage Terraform state?**
Remote state in an Azure storage account with versioning, accessed with Azure AD authentication instead of keys, with state locking through blob leases. Plans are reviewed on pull requests and the apply uses the saved plan after an approval.

**What would you change for production?**
Separate subscriptions or at least resource groups per environment with promotion between them, a private cluster or restricted API access, ingress with TLS, narrower pipeline permissions, Argo CD for GitOps, policy as code, monitoring and alerting with SLOs, and image signing and verification.

**Why Azure CNI overlay?**
It gives pods addresses from a private overlay range instead of consuming VNet IPs, so the subnet can stay small, while still integrating with Azure networking.

**Why not run `kubectl apply` from the pipeline?**
Helm gives versioned, templated, rollback-capable releases, and values per environment. GitOps with Argo CD would go one step further, with the cluster pulling its desired state from Git.

## Things to try yourself (the best interview stories come from these)

1. Break the pipeline on purpose (invalid Terraform, a failing Trivy scan, a bad readiness probe) and show how each gate catches it.
2. Deploy a bad image and watch `--atomic` roll it back.
3. Remove the role assignment for the workload identity and see the pod fail to mount the secret; diagnose it with `kubectl describe pod` and the CSI driver logs.
4. Rotate the secret in Key Vault and observe the update in the pod.
5. Scale load against the app and watch the HPA and the cluster autoscaler react.
