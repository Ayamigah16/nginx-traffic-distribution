# Nginx Load Balancing with Terraform

Production-ready infrastructure-as-code for deploying an Nginx load balancer with multiple backend servers on AWS.

[![Infrastructure](https://img.shields.io/badge/Infrastructure-Terraform-7B42BC?style=flat-square&logo=terraform)](https://www.terraform.io/)
[![Cloud](https://img.shields.io/badge/Cloud-AWS-FF9900?style=flat-square&logo=amazon-aws)](https://aws.amazon.com/)
[![Web Server](https://img.shields.io/badge/Web%20Server-Nginx-009639?style=flat-square&logo=nginx)](https://nginx.org/)

## Overview

This project demonstrates **Layer 7 HTTP load balancing** using Nginx, deployed as infrastructure-as-code via Terraform to AWS EC2 instances. It supports multiple load balancing algorithms and provides automated deployment with production-ready configurations.

### Architecture

```
                         Internet
                            │
                    [Internet Gateway]
                            │
                     [VPC: 10.0.0.0/16]
                            │
              ┌─────────────┴─────────────┐
              │                           │
        [Subnet eu-west-1a]         [Subnet eu-west-1b]
              │                           │
    ┌─────────┴─────────┐         ┌───────┴───────┐
    │                   │         │               │
[Load Balancer]   [Server 1]   [Server 2]
  Port 80         Port 8081     Port 8082
  Elastic IP      Private IP    Private IP
```

### Features

- ✅ **Multiple Load Balancing Algorithms**: Round Robin, Least Connections, IP Hash, Weighted
- ✅ **Infrastructure as Code**: Complete Terraform configuration for AWS
- ✅ **Automated Deployment**: One-command deployment and teardown
- ✅ **Production Ready**: Health checks, monitoring, encrypted volumes
- ✅ **Single Source of Truth**: Configuration files from repository
- ✅ **Cost Optimized**: AWS Free Tier compatible (t3.micro instances)

## Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- AWS EC2 Key Pair in eu-west-1 region

### Deploy Infrastructure

```bash
# 1. Clone the repository
git clone <repository-url>
cd nginx-traffic-distribution

# 2. Configure Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Set your AWS key pair name

# 3. Deploy (automated)
./scripts/deploy.sh

# Or manually:
terraform init
terraform plan
terraform apply
```

### Access Your Load Balancer

After deployment, Terraform will output:
```
load_balancer_public_ip = "34.240.x.x"
load_balancer_url = "http://34.240.x.x"
```

Visit the URL to see your load balancer in action!

### Test Load Distribution

```bash
# Test traffic distribution
for i in {1..20}; do
  curl -s http://<load-balancer-ip>/server-status | grep server
done

# SSH into servers
./scripts/ssh-connect.sh
```

### Cleanup

```bash
./scripts/destroy.sh
```

## Project Structure

```
nginx-traffic-distribution/
│
├── README.md                          # This file
│
├── server1/                           # Backend Server 1 Configuration
│   ├── nginx.conf                     # Nginx config (port 8081)
│   └── html/
│       └── index.html                 # Static website (purple theme)
│
├── server2/                           # Backend Server 2 Configuration
│   ├── nginx.conf                     # Nginx config (port 8082)
│   └── html/
│       └── index.html                 # Static website (pink theme)
│
├── load-balancer/                     # Load Balancer Configurations
│   ├── nginx-round-robin.conf         # Round Robin algorithm
│   ├── nginx-least-conn.conf          # Least Connections algorithm
│   ├── nginx-ip-hash.conf             # IP Hash (session persistence)
│   ├── nginx-weighted.conf            # Weighted distribution
│   └── nginx-health-check.conf        # Production with health checks
│
├── scripts/                           # Local Testing Scripts
│   ├── start-servers.sh               # Start servers locally
│   ├── stop-servers.sh                # Stop servers
│   ├── test-load-balancer.sh          # Test distribution
│   └── monitor-traffic.sh             # Monitor traffic
│
└── terraform/                         # Infrastructure as Code
    ├── main.tf                        # Main infrastructure resources
    ├── variables.tf                   # Input variables
    ├── outputs.tf                     # Output values
    ├── provider.tf                    # AWS provider config
    ├── terraform.tfvars.example       # Configuration template
    ├── README.md                      # Terraform documentation
    │
    ├── scripts/                       # Deployment Automation
    │   ├── deploy.sh                  # Automated deployment
    │   ├── destroy.sh                 # Safe teardown
    │   └── ssh-connect.sh             # SSH helper
    │
    └── user-data/                     # EC2 Bootstrap Scripts
        ├── load-balancer.sh           # Load balancer setup
        ├── backend-server1.sh         # Server 1 setup
        └── backend-server2.sh         # Server 2 setup
```

## Load Balancing Algorithms

Configure via `lb_algorithm` variable in `terraform.tfvars`:

| Algorithm | Value | Description | Use Case |
|-----------|-------|-------------|----------|
| **Round Robin** | `round_robin` | Sequential distribution | Equal servers, stateless apps |
| **Least Connections** | `least_conn` | Routes to least busy | Varying request durations |
| **IP Hash** | `ip_hash` | Client IP based routing | Session persistence needed |
| **Weighted** | `weighted` | Custom traffic ratios | Different server capacities |

Example configuration:
```hcl
lb_algorithm   = "least_conn"
server1_weight = 3  # Used only with "weighted"
server2_weight = 1
```

## Infrastructure Resources

### AWS Resources Created

- **Networking**: 1 VPC, 2 Subnets (multi-AZ), Internet Gateway, Route Table
- **Compute**: 3 × t3.micro EC2 instances (Ubuntu 22.04)
- **Network**: 1 Elastic IP (load balancer)
- **Security**: 2 Security Groups with restrictive rules
- **Storage**: 3 × 8GB encrypted EBS volumes

### Cost Estimate

**Monthly Cost (eu-west-1)**:
- 3 × t3.micro: ~$22.78/month
- 3 × 8GB EBS: ~$2.40/month
- **Total: ~$25/month**

**With AWS Free Tier** (first 12 months):
- 750 hours/month t3.micro: FREE
- 30GB EBS: FREE
- **Your Cost: ~$0-3/month**

## Configuration

### Terraform Variables

Key variables in `terraform.tfvars`:

```hcl
# AWS Configuration
aws_region   = "eu-west-1"           # Ireland region
project_name = "nginx-lb-tutorial"
instance_type = "t3.micro"           # Free Tier eligible

# Security (IMPORTANT: Restrict in production!)
allowed_ssh_cidr  = ["YOUR_IP/32"]   # Your IP only
allowed_http_cidr = ["0.0.0.0/0"]    # Public access

# Load Balancing
lb_algorithm   = "round_robin"       # Algorithm choice
server1_weight = 3                   # For weighted algorithm
server2_weight = 1

# Monitoring
enable_monitoring = false            # CloudWatch detailed monitoring
```

### Customization

**Change Backend Server Content**:
```bash
# Edit configuration
nano server1/html/index.html
nano server1/nginx.conf

# Redeploy
terraform apply
```

**Switch Load Balancing Algorithm**:
```bash
# Edit terraform.tfvars
lb_algorithm = "least_conn"

# Apply changes
terraform apply
```

**Add New Algorithm**:
1. Create `load-balancer/nginx-custom.conf`
2. Update `variables.tf` validation to include `"custom"`
3. Set `lb_algorithm = "custom"` in `terraform.tfvars`
4. Deploy with `terraform apply`

## Local Testing (Without AWS)

Test on your local machine without deploying to AWS:

```bash
# Start local servers
./scripts/start-servers.sh

# Choose algorithm interactively
# Servers run on localhost:8081, localhost:8082
# Load balancer on localhost:80

# Test distribution
./scripts/test-load-balancer.sh

# Monitor traffic
./scripts/monitor-traffic.sh

# Stop servers
./scripts/stop-servers.sh
```

## Security Best Practices

- ✅ **Restrict SSH Access**: Set `allowed_ssh_cidr` to your IP only
- ✅ **Use Strong Keys**: Generate secure EC2 key pairs
- ✅ **Enable Encryption**: EBS volumes encrypted by default
- ✅ **Security Groups**: Minimal required ports only
- ✅ **Regular Updates**: Keep systems patched
- ✅ **CloudWatch Logs**: Monitor and audit access
- ✅ **IAM Roles**: Use roles instead of access keys

## Monitoring & Operations

### Check Infrastructure Status

```bash
# View all outputs
terraform output

# Get specific output
terraform output load_balancer_public_ip

# Check resource state
terraform state list
```

### SSH Access

```bash
# Interactive menu
./scripts/ssh-connect.sh

# Direct access
ssh -i ~/.ssh/your-key.pem ubuntu@<load-balancer-ip>

# View logs
ssh ubuntu@<ip> "sudo tail -f /var/log/nginx/access.log"
```

### Health Checks

```bash
# Load balancer health
curl http://<load-balancer-ip>/health

# Backend server health
curl http://<server-ip>:8081/health
curl http://<server-ip>:8082/health

# Server status JSON
curl http://<load-balancer-ip>/status
```

## Troubleshooting

### Common Issues

**Cannot SSH into instances**:
```bash
# Fix key permissions
chmod 400 ~/.ssh/your-key.pem

# Check security group
# Ensure allowed_ssh_cidr includes your IP
```

**502 Bad Gateway**:
```bash
# Wait 2-3 minutes for user-data scripts to complete
# Check logs
ssh ubuntu@<ip> "tail -f /var/log/user-data.log"
```

**Terraform state locked**:
```bash
# Force unlock (use carefully)
terraform force-unlock <LOCK_ID>
```

**EC2 key pair not found**:
```bash
# Verify key exists in AWS
aws ec2 describe-key-pairs --region eu-west-1 --key-name your-key-name
```

## Advanced Usage

### Remote State Storage

Store Terraform state in S3 for team collaboration:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "nginx-lb/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### Multi-Environment Setup

Use Terraform workspaces:

```bash
terraform workspace new production
terraform workspace new staging
terraform workspace select production
terraform apply
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform init
      - run: terraform plan
      - run: terraform apply -auto-approve
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Support

- 📖 **Documentation**: See [terraform/README.md](terraform/README.md)
- 🐛 **Issues**: Report bugs via GitHub Issues
- 💬 **Discussions**: Ask questions in GitHub Discussions

## Acknowledgments

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws)
- [AWS Best Practices](https://aws.amazon.com/architecture/well-architected/)

---

**Built with ❤️ for learning and production use**
