
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# Local values for cost-optimized testing configuration
locals {
  cluster_name = "eks-test-cluster"
  environment  = "test"
  region       = "us-east-1"
  
  # Cost optimization: Use only 2 AZs to minimize NAT Gateway costs
  availability_zones = ["us-east-1a", "us-east-1b"]
  
  # Minimal CIDR blocks for testing
  vpc_cidr = "10.0.0.0/16"
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
  
  # Common tags for easy identification and teardown
  common_tags = {
    Environment   = local.environment
    Project       = "eks-testing"
    ManagedBy     = "terraform"
    CostCenter    = "testing"
    Owner         = "devops-team"
    # Easy teardown identification
    TeardownGroup = "eks-test-infrastructure"
  }
}

# VPC Module - Cost optimized networking
module "vpc" {
  source = "../../modules/vpc"
  
  vpc_name               = "${local.cluster_name}-vpc"
  vpc_cidr              = local.vpc_cidr
  availability_zones    = local.availability_zones
  private_subnet_cidrs  = local.private_subnet_cidrs
  public_subnet_cidrs   = local.public_subnet_cidrs
  cluster_name          = local.cluster_name
  common_tags           = local.common_tags
}

# EKS Cluster Module - Cost optimized for testing
module "eks" {
  source = "../../modules/eks"
  
  cluster_name    = local.cluster_name
  cluster_version = "1.29"
  
  # VPC Configuration
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = concat(module.vpc.private_subnets, module.vpc.public_subnets)
  control_plane_subnet_ids = module.vpc.private_subnets
  private_subnet_ids       = module.vpc.private_subnets
  
  # Cost optimization: Enable public access for testing convenience
  # In production, this should be false
  enable_public_access = true
  public_access_cidrs  = ["0.0.0.0/0"]
  
  # Minimal node configuration for cost optimization
  min_nodes     = 1
  max_nodes     = 2
  desired_nodes = 1
  
  # Disable spot taints for easier testing
  enable_spot_taints = false
  
  # Enable cluster creator admin permissions for testing
  enable_cluster_creator_admin_permissions = true

  # Map IAM principals to Kubernetes RBAC groups so `iamadmin` can use kubectl
  access_entries = {
    iamadmin = {
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/iamadmin"
      kubernetes_groups = ["system:masters"]
    }
  }
  
  common_tags = local.common_tags
  
  depends_on = [module.vpc]
}
