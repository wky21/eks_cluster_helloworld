
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.34.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # VPC Configuration
  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  # Endpoint Configuration - Flexible access (private always enabled, public configurable)
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = var.enable_public_access
  cluster_endpoint_public_access_cidrs = var.public_access_cidrs

  # Enable IRSA for service accounts
  enable_irsa = true

  # Cluster logging - Minimal for cost optimization
  cluster_enabled_log_types = ["audit"]
  cloudwatch_log_group_retention_in_days = 7

  # EKS Managed Node Groups - Cost optimized
  eks_managed_node_groups = {
    cost_optimized = {
      name = "${var.cluster_name}-spot"

      # Instance configuration for cost optimization
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"

      # Scaling configuration - Minimal for testing
      min_size     = var.min_nodes
      max_size     = var.max_nodes
      desired_size = var.desired_nodes

      # Disk configuration - Minimal for cost
      disk_size = 20
      disk_type = "gp3"

      # Network configuration
      subnet_ids = var.private_subnet_ids

      # Labels for identification
      labels = {
        Environment = "testing"
        NodeType    = "cost-optimized"
        InstanceType = "spot"
      }

      # Update configuration
      update_config = {
        max_unavailable_percentage = 50
      }

      # User data for additional configuration
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        # Cost optimization: Disable unnecessary services
        systemctl disable amazon-ssm-agent
      EOT
    }
  }

  # Cluster addons - Essential only for cost optimization
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        replicaCount = 1  # Minimal replicas for cost
        resources = {
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  # Access entries for cluster access
  #access_entries = var.access_entries

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  #map_users = [
  #  {
  #    userarn  = "arn:aws:iam::713881830177:user/iamadmin"
  #    username = "iamadmin"
  #    groups   = ["system:masters"]
  #  }
  #]

  tags = var.common_tags
}
