#######################################################################
# File: providers.tf
#
# Description:
#   Terraform provider configurations for AWS observability stack
#   including AWS, Kubernetes, and Helm providers.
#
# Purpose:
#   Configure required providers with appropriate versions and
#   authentication settings for multi-service deployment.
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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Environment = var.environment
      Repository  = "aws_observability"
    }
  }
}

# Note: Kubernetes and Helm providers are configured in eks.tf
# after the EKS cluster is created to avoid circular dependencies