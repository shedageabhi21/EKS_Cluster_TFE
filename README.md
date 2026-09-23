<div align="center">

# 🚀 EKS Cluster — Terraform

**Reusable Infrastructure-as-Code for a production-shaped EKS cluster on AWS**

Built by doing this manually in the console first, hitting every real-world
gotcha along the way, then codifying it all into a clean `terraform apply`.

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/eks/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](#)

</div>

---

## 📋 Table of Contents

- [What this creates](#-what-this-creates)
- [Prerequisites](#-prerequisites)
- [Usage](#-usage)
- [Tear down](#-tear-down)
- [Remote state (S3 backend)](#-remote-state-s3-backend)
- [Known issues & fixes](#-known-issues-hit-during-development)
- [Key lesson learned](#-key-lesson-learned)
- [Cost reminder](#-cost-reminder)

---

## 📦 What this creates

```
eks-terraform/
├── main.tf                  # terraform {} block — providers, optional backend
├── provider.tf               # AWS provider config + default_tags
├── variables.tf               # every configurable input
├── vpc.tf                      # VPC, 2 public + 2 private subnets, NAT, EKS tags
├── eks.tf                       # EKS cluster + managed node group + core add-ons
├── irsa.tf                       # IAM role for EBS CSI driver (OIDC/IRSA)
├── ebs-csi-addon.tf                # EBS CSI driver add-on, wired to the IRSA role
├── wait.tf                          # time_sleep — avoids a known EKS timing race
├── outputs.tf                        # cluster info + kubectl connect command
└── terraform.tfvars.example           # copy → terraform.tfvars and customize
```

| File | Purpose |
|---|---|
| `main.tf` | Required providers (`aws`, `time`), optional remote backend |
| `provider.tf` | AWS provider config + `default_tags` |
| `variables.tf` | Region, instance type, node counts, etc. |
| `vpc.tf` | VPC + subnets + NAT + EKS auto-discovery tags |
| `eks.tf` | Cluster + managed node group + CoreDNS / kube-proxy / VPC CNI |
| `irsa.tf` | IAM role for the EBS CSI driver, federated via OIDC |
| `ebs-csi-addon.tf` | EBS CSI driver add-on itself |
| `wait.tf` | Short delay to dodge a known EKS module timing bug |
| `outputs.tf` | Cluster info + the exact `kubectl` connect command |

---

## ✅ Prerequisites

```bash
terraform -version           # >= 1.5.0
aws sts get-caller-identity  # confirm AWS CLI is configured
```

---

## 🚀 Usage

```bash
# 1. Configure
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars              # set instance type, node count, cluster name...

# 2. Initialize & preview
terraform init -upgrade
terraform plan

# 3. Create (~15-20 min, unattended)
terraform apply

# 4. Connect kubectl
terraform output configure_kubectl
# → run whatever it prints, e.g.:
aws eks update-kubeconfig --region ap-south-1 --name my-eks-cluster

# 5. Verify
kubectl get nodes
kubectl get pods -A
```

---

## 🧹 Tear down

```bash
terraform destroy
```

> One command removes node group → cluster → add-ons → IRSA role → NAT
> Gateway(s) → subnets → route tables → IGW → VPC, in the correct
> dependency order. **Always run this at the end of a session** — see
> [Cost reminder](#-cost-reminder).

---

## 🗄️ Remote state (S3 backend)

State lives in S3 instead of locally, so it survives even if this machine
disappears.

> [!IMPORTANT]
> **The S3 bucket must exist BEFORE Terraform's backend can point at it.**
> Terraform can't create its own state storage — it needs somewhere to
> write to *before* `init` even runs. Create it as a **separate, one-time
> step**, never as a resource inside this same config (a config can't use
> a bucket as its backend while also trying to create that bucket —
> chicken-and-egg problem, hit this for real during development).

```bash
aws s3api create-bucket \
  --bucket <your-unique-bucket-name> \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

aws s3api put-bucket-versioning \
  --bucket <your-unique-bucket-name> \
  --versioning-configuration Status=Enabled
```

Then point the `backend "s3" {}` block in `main.tf` at it, and `terraform init`.

> [!TIP]
> If you ever change the backend bucket name/config, use
> `terraform init -reconfigure` (start fresh) rather than `-migrate-state`
> (only works if the *old* bucket still exists to migrate from).

---

## 🐛 Known issues hit during development

*(and exactly how each was fixed — so the next debugging session takes
minutes, not hours)*

<details>
<summary><b>1️⃣ Account restricted to Free Tier instance types only</b></summary>

<br>

**Symptom:** Node group stuck in `CREATING` forever, zero EC2 instances
launch, `nodegroup.health.issues` stays empty — no useful error anywhere
in EKS itself.

**Root cause:** only visible via **CloudTrail** (`Event history` → filter
`RunInstances`) — click into the failed event and check `errorCode`:
```
Client.InvalidParameterCombination
"The specified instance type is not eligible for Free Tier."
```
Credit/training AWS accounts are commonly restricted to Free Tier eligible
instance types as a cost-control guardrail — **this is independent of your
credit balance**, it's a hard technical allow-list, not a billing limit.

**Fix:** use `t3.micro` / `t2.micro`.
```bash
aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true \
  --query "InstanceTypes[*].InstanceType"
```
This is why `node_instance_types` defaults to `["t3.micro"]` in this repo.

</details>

<details>
<summary><b>2️⃣ "Too many pods" — system pods stuck Pending, even with nodes Ready</b></summary>

<br>

**Symptom:**
```
kubectl describe pod <pod> -n kube-system
# Events: "0/2 nodes are available: 2 Too many pods."
```

**Root cause:** small instance types have a very low max-pods-per-node
ceiling, driven by **ENI/IP capacity**, not CPU/RAM. `t3.micro` supports
only a handful of pods — easily consumed by DaemonSets alone (`aws-node`,
`kube-proxy`, `eks-pod-identity-agent` — one of each per node).

**Fix:** more, smaller nodes rather than fewer larger ones (can't size up
due to issue #1). This is why `node_desired_size` defaults to `3`, not `1`.

```bash
kubectl get node <node-name> -o jsonpath='{.status.allocatable.pods}'
```

**Bonus gotcha:** the console's cluster-creation wizard silently enabled
`amazon-cloudwatch-observability` and `external-dns` without being asked —
eating pod capacity on already-tight nodes for no benefit. This repo's
`cluster_addons` deliberately only includes `coredns`, `kube-proxy`,
`vpc-cni`, and `aws-ebs-csi-driver`.

</details>

<details>
<summary><b>3️⃣ Security group VPC mismatch on <code>CreateCluster</code></b></summary>

<br>

**Symptom:**
```
InvalidParameterException: Security group(s) [...] are not associated
to the same VPC as the subnets.
```

**Two distinct causes found:**

| Cause | Symptom pattern | Fix |
|---|---|---|
| **(a)** Missing `vpc_id` on the EKS module | Same SG ID fails repeatedly | Add `vpc_id = module.vpc.vpc_id` explicitly |
| **(b)** AWS eventual-consistency race | A **different** SG ID fails each retry | `time_sleep` (see `wait.tf`) between VPC + cluster creation |

> [!NOTE]
> If the exact same security group ID fails twice in a row, suspect
> **stale Terraform state** instead:
> ```bash
> terraform state list | grep security_group
> terraform state show module.eks.aws_security_group.cluster[0] | grep vpc_id
> ```
> Compare against `terraform output vpc_id`. Mismatch → remove the stale
> entry (`terraform state rm ...`) and re-apply.

</details>

<details>
<summary><b>4️⃣ Orphaned resources from interrupted applies ("deposed objects")</b></summary>

<br>

Any failure above can leave partially-created AWS resources behind — an
S3 bucket, VPC, KMS alias, CloudWatch log group — blocking a clean retry
with `AlreadyExistsException`.

> [!TIP]
> **A large "N to destroy" plan is not automatically alarming.** Terraform
> labels leftover copies from a failed replacement as **deposed objects**:
> ```
> # module.eks.aws_security_group.cluster[0] (deposed object 0fea41ee) will be destroyed
> # (left over from a partially-failed replacement of this instance)
> ```
> A deposed object is a safe-to-destroy orphaned duplicate — **not** your
> live resource. What actually matters: search the plan for
> `aws_eks_cluster` / `aws_eks_node_group` with a plain `will be destroyed`
> and **no** "deposed" note. If either shows up that way, stop and
> investigate before applying.

</details>

<details>
<summary><b>5️⃣ EBS CSI driver add-on times out / crash-loops</b></summary>

<br>

**Symptom:**
```
Error: waiting for EKS Add-On (...:aws-ebs-csi-driver) create: timeout
```
```bash
kubectl logs -n kube-system -l app=ebs-csi-controller -c ebs-plugin --tail=30
# UnauthorizedOperation: ... not authorized to perform: ec2:DescribeAvailabilityZones
```

**Root cause:** the driver needs its own dedicated IAM permissions
(create/attach/delete EBS volumes) — it does **not** inherit them from
the node's own IAM role (which only has the 3 basic worker policies).

**Fix — IRSA (IAM Roles for Service Accounts):** grants the specific
`ebs-csi-controller-sa` service account its own scoped role via OIDC
federation. See `irsa.tf` + `ebs-csi-addon.tf`.

> [!NOTE]
> The add-on is a **standalone** `aws_eks_addon` resource, not nested
> inside the `eks` module's `cluster_addons` map — the IRSA role needs
> `module.eks.oidc_provider_arn` (only exists post-cluster-creation),
> while nesting it would need the IRSA ARN *before* the module finishes.
> A circular dependency. Splitting it out with an explicit
> `depends_on = [module.eks, module.ebs_csi_irsa_role]` breaks the cycle.

</details>

<details>
<summary><b>6️⃣ Console shows "Unauthorized" even though <code>kubectl</code> works fine</b></summary>

<br>

**Root cause:** `enable_cluster_creator_admin_permissions = true` only
grants access to the **exact IAM identity that ran `terraform apply`**.
A different console login identity has no Access Entry of its own.

**Fix:**
```bash
aws eks create-access-entry --cluster-name <cluster> \
  --principal-arn <other-user-arn> --region <region>

aws eks associate-access-policy --cluster-name <cluster> \
  --principal-arn <other-user-arn> \
  --policy-arn arn:aws:iam::aws:policy/eks/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster --region <region>
```

</details>

---

## 💡 Key lesson learned

> **AWS Credits ≠ Free Tier eligibility ≠ IAM permissions ≠ Kubernetes RBAC.**

Four separate, independent systems, all of which have to line up:

| # | System | Controls |
|---|---|---|
| 1 | **Credits** | A dollar balance — doesn't restrict *what* you can launch |
| 2 | **Free Tier eligibility** | Account-level technical allow-list on instance types |
| 3 | **IAM policy** | Who can call *AWS* APIs |
| 4 | **EKS Access Entry / RBAC** | Who can call the *Kubernetes* API via `kubectl`/console |

A failure in any one can look identical to a failure in another, from the
error message alone. **When in doubt, check CloudTrail** for the real
underlying API error rather than trusting the higher-level tool's message.

---

## 💰 Cost reminder

| Resource | Approx. cost while running |
|---|---|
| EKS control plane | `$0.10/hour` flat |
| NAT Gateway(s) | `~$0.045/hour` each (`single_nat_gateway = true` → just one) |
| EC2 nodes | Free Tier eligible — cheap/free within Free Tier hours |
| LoadBalancer Service | `~$0.0225/hour` + data, while it exists |

> [!WARNING]
> **Always run `terraform destroy` at the end of a session.** The control
> plane and NAT Gateway(s) bill 24/7 even when the cluster sits idle.

---

<div align="center">

Built hands-on, one error message at a time. 🛠️

</div>
