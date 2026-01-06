# Terraform Configuration

Infrastructure-as-code for deploying Nginx load balancing infrastructure on AWS.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- AWS EC2 Key Pair in eu-west-1 region

## Quick Start

```bash
# 1. Configure
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Set your key_name

# 2. Deploy
./scripts/deploy.sh

# 3. Access
# Outputs will show load balancer IP and SSH commands

# 4. Cleanup
./scripts/destroy.sh
```

## Configuration

### Required Variables

```hcl
# terraform.tfvars
key_name = "your-ec2-key-pair-name"  # REQUIRED
```

### Optional Variables

```hcl
aws_region        = "eu-west-1"      # Default: eu-west-1
project_name      = "nginx-lb"       # Default: nginx-lb-tutorial
instance_type     = "t3.micro"       # Default: t3.micro
lb_algorithm      = "round_robin"    # round_robin | least_conn | ip_hash | weighted
server1_weight    = 3                # For weighted algorithm
server2_weight    = 1
allowed_ssh_cidr  = ["0.0.0.0/0"]    # IMPORTANT: Restrict to your IP
allowed_http_cidr = ["0.0.0.0/0"]
enable_monitoring = false
```

## Load Balancing Algorithms

| Algorithm | Value | Description |
|-----------|-------|-------------|
| Round Robin | `round_robin` | Sequential distribution |
| Least Connections | `least_conn` | Routes to least busy server |
| IP Hash | `ip_hash` | Session persistence via client IP |
| Weighted | `weighted` | Custom traffic ratios |

## Infrastructure Resources

### Created Resources

- **VPC**: 10.0.0.0/16 with DNS support
- **Subnets**: 2 public subnets across AZs
- **Internet Gateway**: For internet access
- **Security Groups**: 
  - Load Balancer: ports 80, 443, 22
  - Backend Servers: ports 8081, 8082, 22
- **EC2 Instances**: 3 × t3.micro (Ubuntu 22.04)
- **Elastic IP**: Static IP for load balancer
- **EBS Volumes**: 3 × 8GB encrypted

### Cost Estimate

**eu-west-1 Region**:
- 3 × t3.micro: ~$22.78/month
- 3 × 8GB EBS: ~$2.40/month
- 1 × Elastic IP: Free (when attached)
- **Total: ~$25/month**

**AWS Free Tier** (first 12 months):
- **Estimated Cost: $0-3/month**

## Deployment Scripts

### deploy.sh

Automated deployment with validation:
- Prerequisites check
- Configuration validation
- Terraform init/plan/apply
- Output display

```bash
./scripts/deploy.sh
```

### destroy.sh

Safe infrastructure teardown:
- Shows current resources
- Double confirmation required
- Complete cleanup

```bash
./scripts/destroy.sh
```

### ssh-connect.sh

Interactive SSH helper:
- Menu-driven server selection
- tmux multi-server support
- Auto-retrieves IPs from Terraform

```bash
./scripts/ssh-connect.sh
```

## Configuration Files

### How It Works

Terraform reads actual configuration files from the repository:

```
Repository Files → Terraform → AWS Servers
────────────────────────────────────────────

server1/nginx.conf
  → templatefile() reads it
  → Passed to user-data script
  → Written to /etc/nginx/nginx.conf on server

load-balancer/nginx-round-robin.conf
  → file() reads based on lb_algorithm
  → IPs replaced with actual private IPs
  → Deployed to load balancer
```

### Customization

**Change backend content**:
```bash
nano ../server1/html/index.html
terraform apply  # Automatically uses new content
```

**Switch algorithm**:
```bash
nano terraform.tfvars  # Change lb_algorithm
terraform apply
```

**Add new algorithm**:
1. Create `../load-balancer/nginx-custom.conf`
2. Update `variables.tf` validation
3. Set `lb_algorithm = "custom"`

## Outputs

After deployment, Terraform provides:

```
load_balancer_public_ip    # Elastic IP address
load_balancer_url          # http://x.x.x.x
server1_public_ip          # Backend server 1 IP
server2_public_ip          # Backend server 2 IP
ssh_command_lb             # SSH to load balancer
ssh_command_server1        # SSH to server 1
ssh_command_server2        # SSH to server 2
```

## Testing

### Health Checks

```bash
# Load balancer health
curl http://$(terraform output -raw load_balancer_public_ip)/health

# Backend servers
curl http://$(terraform output -raw server1_public_ip):8081/health
curl http://$(terraform output -raw server2_public_ip):8082/health
```

### Load Distribution

```bash
# Test traffic distribution
for i in {1..20}; do
  curl -s http://$(terraform output -raw load_balancer_public_ip)/server-status
done
```

### View Logs

```bash
# SSH and view logs
ssh -i ~/.ssh/your-key.pem ubuntu@$(terraform output -raw load_balancer_public_ip)
sudo tail -f /var/log/nginx/access.log
```

## User Data Scripts

Bootstrap scripts that configure servers on first boot:

### load-balancer.sh
- Installs Nginx
- Deploys selected algorithm config
- Replaces localhost with actual IPs
- Configures health checks
- ~100 lines

### backend-server1.sh / backend-server2.sh
- Installs Nginx
- Deploys nginx.conf from repo
- Deploys HTML content from repo
- Sets up health endpoints
- ~80 lines each

## Troubleshooting

### Common Issues

**Key pair not found**:
```bash
aws ec2 describe-key-pairs --region eu-west-1
# Verify your key exists in the region
```

**Permission denied (SSH)**:
```bash
chmod 400 ~/.ssh/your-key.pem
```

**502 Bad Gateway**:
```bash
# Wait 2-3 minutes for user-data to complete
ssh ubuntu@<ip> "tail -f /var/log/user-data.log"
```

**Terraform state locked**:
```bash
terraform force-unlock <LOCK_ID>
```

## Security Best Practices

### Essential Steps

1. **Restrict SSH access**:
```hcl
allowed_ssh_cidr = ["YOUR_IP/32"]  # Not 0.0.0.0/0
```

2. **Use IAM roles** instead of access keys for EC2
3. **Enable CloudWatch** logs for monitoring
4. **Regular updates**: Keep AMIs and packages current
5. **Backup strategy**: Regular snapshots of EBS volumes

### Security Groups

**Load Balancer**:
- Ingress: 80 (HTTP), 443 (HTTPS), 22 (SSH)
- Egress: All

**Backend Servers**:
- Ingress: 8081-8082 (from LB only), 22 (SSH), ICMP
- Egress: All

## Advanced Configuration

### Remote State

For team collaboration, use S3 backend:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "nginx-lb/terraform.tfstate"
    region = "eu-west-1"
  }
}
```

### Workspaces

Multi-environment support:

```bash
terraform workspace new production
terraform workspace new staging
terraform workspace select production
```

### Auto Scaling

To add auto-scaling for backend servers:

1. Create Launch Template
2. Create Auto Scaling Group
3. Update load balancer to use ASG
4. Configure scaling policies

## File Structure

```
terraform/
├── main.tf                    # Main infrastructure
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── provider.tf                # AWS provider config
├── terraform.tfvars.example   # Configuration template
├── .gitignore                 # Ignore sensitive files
│
├── scripts/
│   ├── deploy.sh              # Automated deployment
│   ├── destroy.sh             # Safe teardown
│   └── ssh-connect.sh         # SSH helper
│
└── user-data/
    ├── load-balancer.sh       # LB bootstrap
    ├── backend-server1.sh     # Server 1 bootstrap
    └── backend-server2.sh     # Server 2 bootstrap
```

## Validation

### Pre-deployment Checks

```bash
# Format code
terraform fmt

# Validate configuration
terraform validate

# Security scan (optional)
tfsec .
```

### Post-deployment Verification

```bash
# Check resources
terraform state list

# Verify connectivity
curl http://$(terraform output -raw load_balancer_public_ip)

# SSH test
ssh -i ~/.ssh/key.pem ubuntu@$(terraform output -raw load_balancer_public_ip) "nginx -v"
```

## Maintenance

### Update Infrastructure

```bash
# Update single resource
terraform apply -target=aws_instance.backend_server1

# Plan before applying
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

### State Management

```bash
# List resources
terraform state list

# Show resource details
terraform state show aws_instance.load_balancer

# Remove resource from state
terraform state rm aws_instance.backend_server1
```

## Support

- 📖 **Main Documentation**: [../README.md](../README.md)
- 🏗️ **AWS Provider Docs**: [Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws)
- 🐛 **Issues**: Report via GitHub Issues

---

For general project information, see the [main README](../README.md).
