terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }

  }

  # Optional: uncomment and configure to store state remotely instead of
  # locally on this machine. Recommended once more than one person/machine
  # touches this, or once you don't want to risk losing state if this VM
  # disappears.
  #
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "eks/my-first-cluster/terraform.tfstate"
  #   region = "ap-south-1"
  # }

  backend "s3" {
    bucket       = "abhishek-my-lab-bucket-for-tfe"
    key          = "learn-terraform/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }

}
