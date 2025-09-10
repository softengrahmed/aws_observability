#######################################################################
# File: locals.tf
#
# Description:
#   Local value definitions for computed values, common configurations,
#   and reusable expressions across the observability implementation.
#
# Purpose:
#   Centralize common values, reduce code duplication, and provide
#   computed values for resource configuration.
#######################################################################

locals {
  # Common tags applied to all resources
  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    Region      = var.aws_region
    ManagedBy   = "Terraform"
    Purpose     = "Observability"
    Owner       = "DevOps"
  }, var.additional_tags)

  # Naming conventions
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Networking calculations
  public_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 1),  # 10.0.1.0/24
    cidrsubnet(var.vpc_cidr, 8, 2),  # 10.0.2.0/24
  ]
  
  private_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 10), # 10.0.10.0/24
    cidrsubnet(var.vpc_cidr, 8, 11), # 10.0.11.0/24
  ]
  
  # EKS configuration
  eks_cluster_name = "${local.name_prefix}-${var.eks_cluster_name}"
  
  # CloudWatch configuration
  log_group_names = {
    eks_cluster    = "/aws/eks/${local.eks_cluster_name}/cluster"
    eks_nodegroup  = "/aws/eks/${local.eks_cluster_name}/nodegroup"
    ec2_instances  = "/aws/ec2/${local.name_prefix}"
    vpc_flow_logs  = "/aws/vpc/flowlogs"
    cloudtrail     = "/aws/cloudtrail/${local.name_prefix}"
  }
  
  # Instance configurations
  ec2_instances = {
    for i in range(var.ec2_instance_count) : i => {
      name = "${local.name_prefix}-instance-${i + 1}"
      type = var.ec2_instance_type
      az   = var.availability_zones[i % length(var.availability_zones)]
    }
  }
  
  # Security group configurations
  security_groups = {
    eks_cluster = {
      name        = "${local.name_prefix}-eks-cluster"
      description = "Security group for EKS cluster control plane"
    }
    eks_nodes = {
      name        = "${local.name_prefix}-eks-nodes"
      description = "Security group for EKS worker nodes"
    }
    ec2_monitoring = {
      name        = "${local.name_prefix}-ec2-monitoring"
      description = "Security group for EC2 monitoring instances"
    }
    grafana = {
      name        = "${local.name_prefix}-grafana"
      description = "Security group for Grafana workspace"
    }
  }
  
  # ADOT configuration
  adot_config = var.enable_adot_addon ? {
    amp_endpoint = module.aws_prometheus.workspace_prometheus_endpoint
    amp_region   = var.aws_region
  } : null
  
  # Sample applications configuration
  sample_applications = var.deploy_sample_apps ? [
    {
      name      = "nginx-demo"
      namespace = "default"
      image     = "nginx:latest"
      port      = 80
    },
    {
      name      = "prometheus-demo-app"
      namespace = "default"
      image     = "quay.io/prometheus/demo-app:latest"
      port      = 8080
    }
  ] : []
  
  # Cost optimization settings
  ec2_instance_market_options = var.enable_spot_instances && var.environment != "production" ? {
    market_type = "spot"
    spot_options = {
      instance_interruption_behavior = "terminate"
      max_price                      = "0.10"
      spot_instance_type            = "one-time"
    }
  } : null
  
  # Environment-specific configurations
  environment_configs = {
    production = {
      log_retention_days     = 90
      backup_retention_days  = 30
      monitoring_interval    = "1m"
      enable_ha             = true
      instance_monitoring   = true
    }
    staging = {
      log_retention_days     = 30
      backup_retention_days  = 7
      monitoring_interval    = "1m"
      enable_ha             = false
      instance_monitoring   = true
    }
    development = {
      log_retention_days     = 14
      backup_retention_days  = 3
      monitoring_interval    = "5m"
      enable_ha             = false
      instance_monitoring   = var.enable_detailed_monitoring
    }
    testing = {
      log_retention_days     = 7
      backup_retention_days  = 1
      monitoring_interval    = "5m"
      enable_ha             = false
      instance_monitoring   = false
    }
    nonprod = {
      log_retention_days     = 7
      backup_retention_days  = 1
      monitoring_interval    = "5m"
      enable_ha             = false
      instance_monitoring   = false
    }
  }
  
  # Current environment configuration
  current_env_config = local.environment_configs[var.environment]
  
  # CloudWatch agent configuration
  cloudwatch_agent_config = {
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "cwagent"
    }
    metrics = {
      namespace = "AWS/EC2/Custom"
      metrics_collected = {
        cpu = {
          measurement = ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"]
          metrics_collection_interval = 60
          totalcpu = false
        }
        disk = {
          measurement = ["used_percent"]
          metrics_collection_interval = 60
          resources = ["*"]
        }
        diskio = {
          measurement = ["io_time"]
          metrics_collection_interval = 60
          resources = ["*"]
        }
        mem = {
          measurement = ["mem_used_percent"]
          metrics_collection_interval = 60
        }
        netstat = {
          measurement = ["tcp_established", "tcp_time_wait"]
          metrics_collection_interval = 60
        }
        processes = {
          measurement = ["running", "sleeping", "dead"]
          metrics_collection_interval = 60
        }
      }
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path         = "/var/log/messages"
              log_group_name    = local.log_group_names.ec2_instances
              log_stream_name   = "{instance_id}/var/log/messages"
              timestamp_format  = "%b %d %H:%M:%S"
            }
          ]
        }
      }
    }
  }
}