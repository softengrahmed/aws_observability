#######################################################################
# File: main.tf
#
# Description:
#   Root module orchestrating AWS observability stack with managed
#   Prometheus and Grafana for EC2 and EKS monitoring.
#
# Purpose:
#   Complete observability implementation demonstrating AMP & AMG
#   integration with CloudWatch and AWS Distro for OpenTelemetry.
#
# Architecture:
#   - EKS cluster with ADOT add-on for metrics collection
#   - EC2 instances with CloudWatch agent
#   - AWS Managed Prometheus for metrics storage
#   - AWS Managed Grafana for visualization
#   - CloudWatch for logs and AWS service metrics
#######################################################################

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# AWS Managed Prometheus Module
module "aws_prometheus" {
  source = "git::https://github.com/softengrahmed/aws_prometheus.git"

  workspace_alias              = var.prometheus_workspace_alias
  environment                 = var.environment
  region                      = var.aws_region
  
  enable_alertmanager         = var.enable_alertmanager
  enable_recording_rules      = var.enable_recording_rules
  create_default_rules        = var.create_default_rules
  
  eks_cluster_names          = [aws_eks_cluster.observability_cluster.name]
  enable_cross_region_access = false
  enable_high_availability   = false
  
  retention_period_days      = var.prometheus_retention_days
  scrape_interval           = var.prometheus_scrape_interval
  
  logging_configuration = {
    log_group_arn = aws_cloudwatch_log_group.prometheus_logs.arn
  }
  
  tags = local.common_tags
}

# AWS Managed Grafana Module  
module "aws_grafana" {
  source = "git::https://github.com/softengrahmed/grafana.git"
  
  workspace_name        = var.grafana_workspace_name
  workspace_description = var.grafana_workspace_description
  environment          = var.environment
  
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type         = "SERVICE_MANAGED"
  
  data_sources = [
    "PROMETHEUS",
    "CLOUDWATCH"
  ]
  
  notification_destinations = ["SNS"]
  grafana_version          = var.grafana_version
  
  # Auto-configure Prometheus data source
  prometheus_workspaces = [
    {
      workspace_arn = module.aws_prometheus.workspace_arn
      alias         = "primary-prometheus"
      region        = var.aws_region
    }
  ]
  
  create_default_dashboards = true
  
  # VPC configuration for private access
  vpc_configuration = var.enable_private_grafana ? {
    security_group_ids = [aws_security_group.grafana[0].id]
    subnet_ids         = aws_subnet.private[*].id
  } : null
  
  tags = local.common_tags
  
  depends_on = [
    module.aws_prometheus,
    aws_eks_cluster.observability_cluster
  ]
}

# SNS Topic for Grafana notifications
resource "aws_sns_topic" "grafana_notifications" {
  name = "${var.project_name}-grafana-notifications"
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-grafana-notifications"
  })
}

resource "aws_sns_topic_subscription" "grafana_notifications_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.grafana_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "prometheus_logs" {
  name              = "/aws/prometheus/${var.prometheus_workspace_alias}"
  retention_in_days = var.environment == "production" ? 90 : 30
  
  tags = merge(local.common_tags, {
    Name = "/aws/prometheus/${var.prometheus_workspace_alias}"
  })
}

resource "aws_cloudwatch_log_group" "grafana_logs" {
  name              = "/aws/grafana/${var.grafana_workspace_name}"
  retention_in_days = var.environment == "production" ? 90 : 30
  
  tags = merge(local.common_tags, {
    Name = "/aws/grafana/${var.grafana_workspace_name}"
  })
}