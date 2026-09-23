variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across (need at least 2 for EKS)"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ) — worker nodes live here"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway instead of one per AZ. Set true to cut NAT cost roughly in half for learning/dev — set false for production-grade per-AZ resilience."
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "EC2 instance type(s) for the managed node group. IMPORTANT: some AWS credit/training accounts are restricted to Free Tier eligible types only (e.g. t3.micro, t2.micro) — check with: aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes. NOTE: small instance types (t3.micro) have a low max-pods-per-node ceiling due to ENI limits — you may need more, smaller nodes rather than fewer, larger ones."
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 6
}

variable "node_disk_size" {
  description = "EBS root volume size (GiB) per worker node"
  type        = number
  default     = 20
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Automatically grant the identity running terraform apply cluster-admin access (avoids the manual 'Access entry' step we had to do by hand in the console)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "eks-learning"
    ManagedBy = "terraform"
  }
}
