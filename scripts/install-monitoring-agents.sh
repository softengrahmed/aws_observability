#!/bin/bash
#######################################################################
# File: scripts/install-monitoring-agents.sh
#
# Description:
#   Bootstrap script for EC2 instances to install CloudWatch agent,
#   Prometheus node exporter, and configure monitoring components.
#
# Purpose:
#   Automated installation and configuration of monitoring agents
#   for comprehensive observability with AMP and AMG integration.
#
# Template Variables:
#   - prometheus_endpoint: AMP workspace endpoint
#   - aws_region: AWS region for service calls
#   - project_name: Project identifier
#   - environment: Environment name
#   - ssm_parameter_name: CloudWatch agent config parameter
#######################################################################

set -euo pipefail

# Variables from Terraform template
PROMETHEUS_ENDPOINT="${prometheus_endpoint}"
AWS_REGION="${aws_region}"
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
SSM_PARAMETER_NAME="${ssm_parameter_name}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/monitoring-setup.log
}

log "Starting monitoring agent installation for $PROJECT_NAME in $ENVIRONMENT environment"

# Update system packages
log "Updating system packages..."
yum update -y

# Install required packages
log "Installing required packages..."
yum install -y \
    wget \
    curl \
    unzip \
    htop \
    jq \
    awscli \
    amazon-cloudwatch-agent \
    collectd

# Install AWS CLI v2 if not already present
if ! aws --version | grep "aws-cli/2"; then
    log "Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws/
fi

# Configure CloudWatch agent
log "Configuring CloudWatch agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c ssm:$SSM_PARAMETER_NAME

# Enable and start CloudWatch agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Install Prometheus Node Exporter
log "Installing Prometheus Node Exporter..."
NODEEXPORTER_VERSION="1.6.1"
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v$NODEEXPORTER_VERSION/node_exporter-$NODEEXPORTER_VERSION.linux-amd64.tar.gz
tar xvfz node_exporter-$NODEEXPORTER_VERSION.linux-amd64.tar.gz
mv node_exporter-$NODEEXPORTER_VERSION.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-$NODEEXPORTER_VERSION.linux-amd64*

# Create node_exporter user
useradd -rs /bin/false node_exporter

# Create systemd service for node_exporter
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Enable and start node_exporter
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Install and configure Prometheus for remote write to AMP
log "Installing Prometheus for remote write..."
PROMETHEUS_VERSION="2.45.0"
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
tar xvfz prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
mv prometheus-$PROMETHEUS_VERSION.linux-amd64/prometheus /usr/local/bin/
mv prometheus-$PROMETHEUS_VERSION.linux-amd64/promtool /usr/local/bin/
rm -rf prometheus-$PROMETHEUS_VERSION.linux-amd64*

# Create prometheus user and directories
useradd -rs /bin/false prometheus
mkdir -p /etc/prometheus /var/lib/prometheus
chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Create Prometheus configuration for remote write to AMP
cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 30s
  evaluation_interval: 30s

scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
    scrape_interval: 15s
    metrics_path: /metrics

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 15s

remote_write:
  - url: $PROMETHEUS_ENDPOINT/api/v1/remote_write
    queue_config:
      max_samples_per_send: 1000
      max_shards: 200
      capacity: 2500
    sigv4:
      region: $AWS_REGION
EOF

chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Create systemd service for Prometheus
cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file /etc/prometheus/prometheus.yml \
  --storage.tsdb.path /var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle \
  --storage.tsdb.retention.time=1d
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Prometheus
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# Install and configure a sample web application (nginx with custom metrics)
log "Installing sample web application..."
yum install -y nginx

# Create a simple index page
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$PROJECT_NAME - Monitoring Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { color: #232F3E; }
        .metrics { background: #f5f5f5; padding: 20px; margin: 20px 0; }
        .status { color: green; font-weight: bold; }
    </style>
</head>
<body>
    <h1 class="header">AWS Observability Demo</h1>
    <h2>Project: $PROJECT_NAME</h2>
    <h3>Environment: $ENVIRONMENT</h3>
    <div class="metrics">
        <h4>Monitoring Endpoints:</h4>
        <ul>
            <li><a href="http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9100/metrics">Node Exporter Metrics</a></li>
            <li><a href="http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090">Prometheus Interface</a></li>
            <li><a href="/nginx_status">Nginx Status</a></li>
        </ul>
    </div>
    <p class="status">Monitoring agents are active and sending metrics to AMP!</p>
    <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
    <p>Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)</p>
    <p>Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
</body>
</html>
EOF

# Configure nginx status endpoint
cat >> /etc/nginx/nginx.conf << 'EOF'

    # Status endpoint for monitoring
    server {
        listen 80;
        server_name localhost;
        
        location /nginx_status {
            stub_status on;
            access_log off;
            allow 127.0.0.1;
            allow 10.0.0.0/8;
            deny all;
        }
    }
EOF

# Enable and start nginx
systemctl enable nginx
systemctl start nginx

# Create a simple metrics generation script
cat > /usr/local/bin/generate-sample-metrics.sh << 'EOF'
#!/bin/bash
# Generate sample application metrics

METRICS_FILE="/var/log/application-metrics.log"

while true; do
    # Generate random metrics
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    RESPONSE_TIME=$((RANDOM % 500 + 50))
    STATUS_CODE=$(( (RANDOM % 100 < 95) ? 200 : 500 ))
    
    echo "$TIMESTAMP response_time=$RESPONSE_TIME status=$STATUS_CODE" >> $METRICS_FILE
    
    # Rotate log if it gets too large
    if [ $(stat -f%z "$METRICS_FILE" 2>/dev/null || stat -c%s "$METRICS_FILE") -gt 10485760 ]; then
        mv $METRICS_FILE $METRICS_FILE.old
        touch $METRICS_FILE
    fi
    
    sleep $(( RANDOM % 30 + 10 ))
done
EOF

chmod +x /usr/local/bin/generate-sample-metrics.sh

# Create systemd service for sample metrics generation
cat > /etc/systemd/system/sample-metrics.service << EOF
[Unit]
Description=Sample Metrics Generator
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/generate-sample-metrics.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sample-metrics
systemctl start sample-metrics

# Configure rsyslog to send logs to CloudWatch
log "Configuring log forwarding..."
cat >> /etc/rsyslog.conf << EOF

# Forward application logs to CloudWatch agent
*.info @@127.0.0.1:25224
EOF

systemctl restart rsyslog

# Install AWS X-Ray daemon for tracing (optional)
log "Installing AWS X-Ray daemon..."
cd /tmp
wget https://s3.us-east-2.amazonaws.com/aws-xray-assets.us-east-2/xray-daemon/aws-xray-daemon-3.x.rpm
yum install -y aws-xray-daemon-3.x.rpm
rm -f aws-xray-daemon-3.x.rpm

# Configure X-Ray daemon
cat > /etc/amazon/xray/cfg.yaml << EOF
TotalBufferSizeKB: 0
Concurrency: 8
Region: $AWS_REGION
NoVerifySSL: false
LocalMode: false
ResourceARN: ""
RoleARN: ""
ProxyAddress: ""
DaemonAddress: "0.0.0.0:2000"
LogLevel: prod
LogRotation: true
EOF

systemctl enable xray
systemctl start xray

# Create a health check script
cat > /usr/local/bin/health-check.sh << 'EOF'
#!/bin/bash
# Health check script for monitoring agents

echo "=== Monitoring Agents Health Check ==="
echo "Date: $(date)"
echo

echo "CloudWatch Agent Status:"
systemctl is-active amazon-cloudwatch-agent || echo "FAILED"

echo "Node Exporter Status:"
systemctl is-active node_exporter || echo "FAILED"
curl -s http://localhost:9100/metrics > /dev/null && echo "Metrics endpoint OK" || echo "Metrics endpoint FAILED"

echo "Prometheus Status:"
systemctl is-active prometheus || echo "FAILED"
curl -s http://localhost:9090/-/healthy > /dev/null && echo "Prometheus healthy" || echo "Prometheus FAILED"

echo "Nginx Status:"
systemctl is-active nginx || echo "FAILED"
curl -s http://localhost/nginx_status > /dev/null && echo "Nginx status OK" || echo "Nginx status FAILED"

echo "X-Ray Daemon Status:"
systemctl is-active xray || echo "FAILED"

echo "Sample Metrics Generator:"
systemctl is-active sample-metrics || echo "FAILED"

echo "=== End Health Check ==="
EOF

chmod +x /usr/local/bin/health-check.sh

# Create cron job for periodic health checks
echo "*/5 * * * * root /usr/local/bin/health-check.sh >> /var/log/health-check.log 2>&1" >> /etc/crontab

# Final status check
log "Installation completed. Running health check..."
/usr/local/bin/health-check.sh

log "Monitoring setup completed successfully!"
log "Services started:"
log "- CloudWatch Agent: $(systemctl is-active amazon-cloudwatch-agent)"
log "- Node Exporter: $(systemctl is-active node_exporter)"
log "- Prometheus: $(systemctl is-active prometheus)"
log "- Nginx: $(systemctl is-active nginx)"
log "- X-Ray Daemon: $(systemctl is-active xray)"
log "- Sample Metrics: $(systemctl is-active sample-metrics)"

# Signal that user data script has completed
/opt/aws/bin/cfn-signal -e $? --stack ${AWS::StackName} --resource AutoScalingGroup --region $AWS_REGION || true