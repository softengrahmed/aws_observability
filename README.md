# AWS Observability Implementation

A comprehensive AWS observability solution demonstrating Amazon Managed Prometheus (AMP) and Amazon Managed Grafana (AMG) integration with EC2 and EKS workloads.

## 🏗️ **Architecture Overview**

This implementation provides a complete observability stack for AWS workloads using:

- **AWS Managed Prometheus (AMP)** - Scalable metrics storage and querying
- **AWS Managed Grafana (AMG)** - Visualization and dashboarding platform  
- **Amazon EKS** - Kubernetes cluster with ADOT for metrics collection
- **Amazon EC2** - Virtual machines with CloudWatch agent monitoring
- **AWS CloudWatch** - Centralized logging and basic monitoring
- **AWS Distro for OpenTelemetry (ADOT)** - Metrics and traces collection

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   EKS Cluster   │    │  EC2 Instances  │    │   CloudWatch    │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │    ADOT     │ │    │ │ CW Agent    │ │    │ │    Logs     │ │
│ │  Collector  │ │    │ │Node Exporter│ │    │ │  Metrics    │ │
│ └─────────────┘ │    │ │ Prometheus  │ │    │ │  Alarms     │ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │      AMP        │
                    │   (Metrics      │
                    │    Storage)     │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │      AMG        │
                    │ (Visualization) │
                    └─────────────────┘
```

## ✨ **Features**

### **Core Observability Stack**
- ✅ **AWS Managed Prometheus** workspace with AlertManager and recording rules
- ✅ **AWS Managed Grafana** workspace with pre-configured dashboards
- ✅ **EKS cluster** with AWS Distro for OpenTelemetry (ADOT) add-on
- ✅ **EC2 instances** with CloudWatch agent and Prometheus node exporter
- ✅ **CloudWatch integration** for logs, metrics, and alarms

### **Monitoring & Alerting**
- 🔔 **Comprehensive alerting** via CloudWatch alarms and SNS notifications
- 📊 **Pre-built dashboards** for Kubernetes, infrastructure, and applications
- 📈 **Custom metrics** collection from applications and infrastructure
- 🎯 **Recording rules** for optimized query performance
- 🚨 **Health checks** and automated monitoring agent validation

### **Sample Applications**
- 🐳 **Kubernetes workloads** (NGINX and Prometheus demo app)
- 🌐 **Web server** with custom metrics generation
- 📦 **Container insights** with enhanced observability
- 🔍 **Distributed tracing** with AWS X-Ray integration

### **Security & Compliance**
- 🔒 **IAM roles** with least-privilege access
- 🛡️ **VPC networking** with private subnets and security groups
- 🔐 **Encryption at rest** for supported services
- 📋 **CloudTrail logging** for API audit trails
- 🌊 **VPC Flow Logs** for network monitoring

### **Cost Optimization**
- 💰 **Spot instances** support for non-production environments
- ⏰ **Configurable log retention** based on environment
- 🎛️ **Feature flags** to disable expensive components
- 📊 **Environment-aware** resource sizing

## 🚀 **Quick Start**

### **Prerequisites**
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl (for EKS management)

### **Basic Deployment**

1. **Clone the repository**
   ```bash
   git clone https://github.com/softengrahmed/aws_observability.git
   cd aws_observability
   ```

2. **Configure variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Deploy the infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Configure kubectl for EKS**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name aws-observability-demo-development-observability-cluster
   ```

5. **Access Grafana**
   ```bash
   # Get the Grafana URL from outputs
   terraform output grafana_login_url
   ```

## 📋 **Configuration**

### **Environment Variables**

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project_name` | Project identifier | `aws-observability-demo` | No |
| `environment` | Environment name | `development` | No |
| `aws_region` | AWS region | `us-east-1` | No |
| `notification_email` | Email for alerts | `""` | No |

### **Key Configuration Options**

```hcl
# Enable/disable major components
enable_alertmanager     = true
enable_recording_rules  = true
deploy_sample_apps     = true
enable_spot_instances  = false  # Cost optimization

# Scaling configuration
eks_node_group_desired_size = 2
ec2_instance_count         = 2

# Security configuration
allowed_cidr_blocks = ["10.0.0.0/8"]  # Restrict for production
enable_encryption   = true
```

## 🛠️ **Module Integration**

This implementation uses the following external modules:

### **AWS Managed Prometheus Module**
```hcl
module "aws_prometheus" {
  source = "git::https://github.com/softengrahmed/aws_prometheus.git"
  
  workspace_alias        = var.prometheus_workspace_alias
  environment           = var.environment
  enable_alertmanager   = var.enable_alertmanager
  enable_recording_rules = var.enable_recording_rules
  eks_cluster_names     = [aws_eks_cluster.observability_cluster.name]
}
```

### **AWS Managed Grafana Module**
```hcl
module "aws_grafana" {
  source = "git::https://github.com/softengrahmed/grafana.git"
  
  workspace_name           = var.grafana_workspace_name
  environment             = var.environment
  authentication_providers = ["AWS_SSO"]
  data_sources           = ["PROMETHEUS", "CLOUDWATCH"]
  
  prometheus_workspaces = [
    {
      workspace_arn = module.aws_prometheus.workspace_arn
      alias        = "primary-prometheus"
      region       = var.aws_region
    }
  ]
}
```

## 📊 **Monitoring Endpoints**

After deployment, the following monitoring endpoints are available:

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Grafana | `https://<workspace-id>.grafana-workspace.<region>.amazonaws.com/` | Dashboards and visualization |
| Prometheus | Via Grafana data source | Metrics querying |
| Node Exporter | `http://<ec2-ip>:9100/metrics` | System metrics |
| CloudWatch | AWS Console | Logs and basic metrics |
| EKS Dashboards | Grafana | Kubernetes monitoring |

## 📈 **Pre-configured Dashboards**

The implementation includes ready-to-use dashboards for:

- **Infrastructure Overview** - EC2 instances, networking, storage
- **Kubernetes Overview** - Cluster health, pod metrics, resource usage  
- **Application Overview** - Custom application metrics and performance
- **CloudWatch Integration** - AWS service metrics and logs

## 🔧 **Customization**

### **Adding Custom Metrics**

1. **EC2 Instances**: Modify the CloudWatch agent configuration in `locals.tf`
2. **Kubernetes**: Add annotations to pods for Prometheus scraping
3. **Applications**: Use the Prometheus client libraries to expose metrics

### **Custom Dashboards**

Add dashboard JSON files to the `dashboards/` directory and reference them in `dashboards.tf`.

### **Alerting Rules**

Customize alerting rules by modifying the AlertManager configuration templates in the AMP module.

## 🛡️ **Security Considerations**

### **Production Deployment**

- Set `allowed_cidr_blocks` to restrict network access
- Enable `enable_private_grafana` for VPC-only access
- Use specific IAM roles instead of broad permissions
- Enable encryption for all supported services
- Configure proper log retention policies

### **IAM Permissions**

The implementation creates IAM roles with minimal required permissions:
- EKS cluster and node group roles
- EC2 instance role for CloudWatch agent
- ADOT collector role for metrics forwarding
- Service roles for AMP and AMG

## 💰 **Cost Optimization**

### **Development Environment**
```hcl
environment           = "development"
enable_spot_instances = true
ec2_instance_count   = 1
eks_node_group_desired_size = 1
cloudwatch_log_retention_days = 7
```

### **Production Environment**
```hcl
environment           = "production"
enable_spot_instances = false
ec2_instance_count   = 3
eks_node_group_desired_size = 3
cloudwatch_log_retention_days = 90
```

## 🔍 **Troubleshooting**

### **Common Issues**

1. **EKS Access Issues**
   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster-name>
   kubectl auth can-i get pods
   ```

2. **Grafana Access**
   - Ensure AWS SSO is configured in your account
   - Check IAM permissions for Grafana workspace access

3. **Metrics Not Appearing**
   ```bash
   # Check CloudWatch agent status on EC2
   sudo systemctl status amazon-cloudwatch-agent
   
   # Check ADOT collector in EKS
   kubectl get pods -n amazon-cloudwatch
   ```

4. **High Costs**
   - Enable spot instances for non-production
   - Reduce log retention periods
   - Scale down EKS node groups during off-hours

## 📚 **Additional Resources**

- [AWS Managed Prometheus Documentation](https://docs.aws.amazon.com/prometheus/)
- [AWS Managed Grafana Documentation](https://docs.aws.amazon.com/grafana/)
- [AWS Distro for OpenTelemetry](https://aws-otel.github.io/docs/introduction)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 **Support**

For issues and questions:
- Open a GitHub issue
- Check the troubleshooting section
- Review AWS service documentation

---

**Built with ❤️ for AWS observability**