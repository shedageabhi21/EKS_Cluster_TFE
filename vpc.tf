# Uses the official, widely-used terraform-aws-modules/vpc module instead of
# hand-writing every subnet/route-table/NAT resource individually — this is
# exactly what you clicked through manually in the console ("VPC and more"
# wizard), just declarative and reusable now.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway # true = 1 shared NAT (cheaper), false = 1 per AZ (prod-grade)

  enable_dns_hostnames = true
  enable_dns_support   = true

  # These are the exact tags we had to add BY HAND on every subnet in the
  # console earlier — the module applies them automatically here.
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  tags = var.tags
}
