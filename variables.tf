#######################################################################
# File: variables.tf
#
# Description:
#   Input variable definitions for AWS observability implementation
#   with validation rules and comprehensive configuration options.
#
# Purpose:
#   Define configurable parameters for complete observability stack
#   deployment with environment-specific customization.
#######################################################################

# Project Configuration
variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "aws-observability-demo"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.project_name))
    error_message = "Project name must contain only alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Environment name (development, staging, production, testing, nonprod)"
  type        = string
  default     = "development"
  
  validation {
    condition     = contains(["production", "staging", "development", "testing", "nonprod"], var.environment)
    error_message = "Environment must be one of: production, staging, development, testing, nonprod."
  }
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

# Networking Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# EKS Configuration
variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "observability-cluster"
}

variable "eks_node_group_instance_types" {
  description = "Instance types for EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_group_desired_size" {
  description = "Desired number of nodes in EKS node group"
  type        = number
  default     = 2
}

variable "eks_node_group_max_size" {
  description = "Maximum number of nodes in EKS node group"
  type        = number
  default     = 4
}

variable "eks_node_group_min_size" {
  description = "Minimum number of nodes in EKS node group"
  type        = number
  default     = 1
}

# EC2 Configuration
variable "ec2_instance_type" {
  description = "EC2 instance type for monitoring instances"
  type        = string
  default     = "t3.small"
}

variable "ec2_instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 2
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2"
  type        = bool
  default     = true
}

# Prometheus Configuration
variable "prometheus_workspace_alias" {
  description = "Alias for the Prometheus workspace"
  type        = string
  default     = "observability-prometheus"
}

variable "enable_alertmanager" {
  description = "Enable Alert Manager for Prometheus"
  type        = bool
  default     = true
}

variable "enable_recording_rules" {
  description = "Enable recording rules for Prometheus"
  type        = bool
  default     = true
}

variable "create_default_rules" {
  description = "Create default recording and alerting rules"
  type        = bool
  default     = true
}

variable "prometheus_retention_days" {
  description = "Data retention period for Prometheus in days"
  type        = number
  default     = 150
  
  validation {
    condition     = var.prometheus_retention_days >= 1 && var.prometheus_retention_days <= 450
    error_message = "Prometheus retention period must be between 1 and 450 days."
  }
}

variable "prometheus_scrape_interval" {
  description = "Default scrape interval for Prometheus"
  type        = string
  default     = "30s"
  
  validation {
    condition     = can(regex("^[0-9]+[smh]$", var.prometheus_scrape_interval))
    error_message = "Scrape interval must be in format like '30s', '1m', '5m', etc."
  }
}

# Grafana Configuration
variable "grafana_workspace_name" {
  description = "Name for the Grafana workspace"
  type        = string
  default     = "observability-grafana"
}

variable "grafana_workspace_description" {
  description = "Description for the Grafana workspace"
  type        = string
  default     = "AWS Managed Grafana workspace for observability demo with EC2 and EKS monitoring"
}

variable "grafana_version" {
  description = "Grafana version for the workspace"
  type        = string
  default     = "9.4"
}

variable "enable_private_grafana" {
  description = "Deploy Grafana in private VPC"
  type        = bool
  default     = false
}

# Notification Configuration
variable "notification_email" {
  description = "Email address for notifications (leave empty to disable)"
  type        = string
  default     = ""
}

# CloudWatch Configuration
variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for API logging"
  type        = bool
  default     = true
}

# ADOT Configuration
variable "enable_adot_addon" {
  description = "Enable AWS Distro for OpenTelemetry EKS add-on"
  type        = bool
  default     = true
}

variable "adot_version" {
  description = "Version of ADOT EKS add-on"
  type        = string
  default     = "v0.88.0-eksbuild.1"
}

# Sample Application Configuration
variable "deploy_sample_apps" {
  description = "Deploy sample applications for metrics generation"
  type        = bool
  default     = true
}

# Cost Optimization
variable "enable_spot_instances" {
  description = "Use spot instances for cost optimization (non-production only)"
  type        = bool
  default     = false
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production
}

variable "enable_encryption" {
  description = "Enable encryption for supported services"
  type        = bool
  default     = true
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}