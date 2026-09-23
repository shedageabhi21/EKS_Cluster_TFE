🚀 EKS Cluster — Terraform
Reusable Infrastructure-as-Code for a production-shaped EKS cluster on AWS

Built by doing this manually in the console first, hitting every real-world gotcha along the way, then codifying it all into a clean terraform apply.

Terraform AWS Kubernetes License

📋 Table of Contents
What this creates
Prerequisites
Usage
Tear down
Remote state (S3 backend)
Known issues & fixes
Key lesson learned
Cost reminder
📦 What this creates
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
File	Purpose
main.tf	Required providers (aws, time), optional remote backend
provider.tf	AWS provider config + default_tags
variables.tf	Region, instance type, node counts, etc.
vpc.tf	VPC + subnets + NAT + EKS auto-discovery tags
eks.tf	Cluster + managed node group + CoreDNS / kube-proxy / VPC CNI
irsa.tf	IAM role for the EBS CSI driver, federated via OIDC
ebs-csi-addon.tf	EBS CSI driver add-on itself
wait.tf	Short delay to dodge a known EKS module timing bug
outputs.tf	Cluster info + the exact kubectl connect command
✅ Prerequisites
terraform -version           # >= 1.5.0
aws sts get-caller-identity  # confirm AWS CLI is configured
🚀 Usage
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
🧹 Tear down
terraform destroy
One command removes node group → cluster → add-ons → IRSA role → NAT Gateway(s) → subnets → route tables → IGW → VPC, in the correct dependency order. Always run this at the end of a session — see Cost reminder.

🗄️ Remote state (S3 backend)
State lives in S3 instead of locally, so it survives even if this machine disappears.

[!IMPORTANT] The S3 bucket must exist BEFORE Terraform's backend can point at it. Terraform can't create its own state storage — it needs somewhere to write to before init even runs. Create it as a separate, one-time step, never as a resource inside this same config (a config can't use a bucket as its backend while also trying to create that bucket — chicken-and-egg problem, hit this for real during development).

aws s3api create-bucket \
  --bucket <your-unique-bucket-name> \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

aws s3api put-bucket-versioning \
  --bucket <your-unique-bucket-name> \
  --versioning-configuration Status=Enabled
Then point the backend "s3" {} block in main.tf at it, and terraform init.

[!TIP] If you ever change the backend bucket name/config, use terraform init -reconfigure (start fresh) rather than -migrate-state (only works if the old bucket still exists to migrate from).

🐛 Known issues hit during development
(and exactly how each was fixed — so the next debugging session takes minutes, not hours)

1️⃣ Account restricted to Free Tier instance types only
2️⃣ "Too many pods" — system pods stuck Pending, even with nodes Ready
3️⃣ Security group VPC mismatch on CreateCluster
4️⃣ Orphaned resources from interrupted applies ("deposed objects")
5️⃣ EBS CSI driver add-on times out / crash-loops
6️⃣ Console shows "Unauthorized" even though kubectl works fine
💡 Key lesson learned
AWS Credits ≠ Free Tier eligibility ≠ IAM permissions ≠ Kubernetes RBAC.

Four separate, independent systems, all of which have to line up:

#	System	Controls
1	Credits	A dollar balance — doesn't restrict what you can launch
2	Free Tier eligibility	Account-level technical allow-list on instance types
3	IAM policy	Who can call AWS APIs
4	EKS Access Entry / RBAC	Who can call the Kubernetes API via kubectl/console
A failure in any one can look identical to a failure in another, from the error message alone. When in doubt, check CloudTrail for the real underlying API error rather than trusting the higher-level tool's message.

💰 Cost reminder
Resource	Approx. cost while running
EKS control plane	$0.10/hour flat
NAT Gateway(s)	~$0.045/hour each (single_nat_gateway = true → just one)
EC2 nodes	Free Tier eligible — cheap/free within Free Tier hours
LoadBalancer Service	~$0.0225/hour + data, while it exists
[!WARNING] Always run terraform destroy at the end of a session. The control plane and NAT Gateway(s) bill 24/7 even when the cluster sits idle.

Built hands-on, one error message at a time. 🛠️
