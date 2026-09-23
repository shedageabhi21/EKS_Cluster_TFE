# Copy this file to terraform.tfvars and adjust as needed.
# terraform.tfvars is where you override the defaults in variables.tf
# without touching the module code itself.

aws_region           = "ap-south-1"
azs                  = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
cluster_name         = "my-eks-cluster"
cluster_version      = "1.31"
vpc_cidr             = "10.0.0.0/16"

# IMPORTANT: if your AWS account is Free Tier restricted (common on
# credit/training accounts — we hit this exact issue doing this manually),
# keep this as t3.micro or t2.micro. Check what's allowed with:
#   aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true --query "InstanceTypes[*].InstanceType"
node_instance_types = ["t3.micro"]

# t3.micro has a low max-pods-per-node ceiling (ENI limit), so prefer MORE
# small nodes over FEWER larger ones if you hit "Too many pods" scheduling
# errors, same as we did.
node_desired_size = 5
node_min_size     = 2
node_max_size     = 6
node_disk_size    = 20
# true = 1 shared NAT Gateway (cheaper, ~half the NAT cost, fine for learning)
# false = 1 NAT Gateway per AZ (production-grade, survives an AZ outage)
single_nat_gateway = false

tags = {
  Project   = "eks-learning"
  ManagedBy = "terraform"
  Owner     = "your-name"
}
