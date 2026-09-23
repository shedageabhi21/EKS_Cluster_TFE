module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  depends_on      = [time_sleep.wait_for_security_group]
  vpc_id = module.vpc.vpc_id
  cluster_endpoint_public_access = true

  # Control plane ENIs span ALL 4 subnets (public + private) — matches
  # what we selected manually in the console's cluster networking step.
  control_plane_subnet_ids = concat(module.vpc.public_subnets, module.vpc.private_subnets)

  # Worker nodes only go in PRIVATE subnets — matches our node group
  # networking choice done by hand.
  subnet_ids = module.vpc.private_subnets
  enable_irsa = true

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      disk_size = var.node_disk_size
    }
  }

  tags = var.tags
}
