# Main Terraform Configuration for Nginx Load Balancing Infrastructure

# Data source for latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "${var.project_name}-lb-sg"
  description = "Security group for Nginx load balancer"
  vpc_id      = aws_vpc.main.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
    description = "HTTP access"
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
    description = "HTTPS access"
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
    description = "SSH access"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-lb-sg"
  }
}

# Security Group for Backend Servers
resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-backend-sg"
  description = "Security group for backend servers"
  vpc_id      = aws_vpc.main.id

  # Application ports from load balancer
  ingress {
    from_port       = 8081
    to_port         = 8082
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
    description     = "Backend ports from load balancer"
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
    description = "SSH access"
  }

  # Allow direct HTTP access for testing (optional - can be removed in production)
  ingress {
    from_port   = 8081
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
    description = "Direct HTTP access for testing"
  }

  # ICMP for ping
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
    description = "ICMP within VPC"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-backend-sg"
  }
}

# Load Balancer EC2 Instance
resource "aws_instance" "load_balancer" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.lb_sg.id]
  monitoring             = var.enable_monitoring
  
  disable_api_termination = var.enable_termination_protection

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user-data/load-balancer.sh", {
    server1_ip     = aws_instance.backend_server1.private_ip
    server2_ip     = aws_instance.backend_server2.private_ip
    lb_algorithm   = var.lb_algorithm
    server1_weight = var.server1_weight
    server2_weight = var.server2_weight
    nginx_conf     = file("${path.module}/../load-balancer/nginx-${replace(var.lb_algorithm, "_", "-")}.conf")
  })

  tags = {
    Name = "${var.project_name}-load-balancer"
    Role = "LoadBalancer"
  }

  depends_on = [
    aws_instance.backend_server1,
    aws_instance.backend_server2
  ]
}

# Elastic IP for Load Balancer
resource "aws_eip" "load_balancer" {
  domain   = "vpc"
  instance = aws_instance.load_balancer.id

  tags = {
    Name = "${var.project_name}-lb-eip"
    Role = "LoadBalancer"
  }

  depends_on = [aws_internet_gateway.main]
}

# Backend Server 1
resource "aws_instance" "backend_server1" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  monitoring             = var.enable_monitoring
  
  disable_api_termination = var.enable_termination_protection

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user-data/backend-server1.sh", {
    nginx_conf = file("${path.module}/../server1/nginx.conf")
    html_content = file("${path.module}/../server1/html/index.html")
  })

  tags = {
    Name        = "${var.project_name}-backend-server-1"
    Role        = "BackendServer"
    ServerID    = "1"
    ServerPort  = "8081"
  }
}

# Backend Server 2
resource "aws_instance" "backend_server2" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public[1].id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  monitoring             = var.enable_monitoring
  
  disable_api_termination = var.enable_termination_protection

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user-data/backend-server2.sh", {
    nginx_conf = file("${path.module}/../server2/nginx.conf")
    html_content = file("${path.module}/../server2/html/index.html")
  })

  tags = {
    Name        = "${var.project_name}-backend-server-2"
    Role        = "BackendServer"
    ServerID    = "2"
    ServerPort  = "8082"
  }
}

# CloudWatch Alarms (Optional - only if monitoring is enabled)
resource "aws_cloudwatch_metric_alarm" "lb_cpu" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-lb-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors load balancer CPU utilization"

  dimensions = {
    InstanceId = aws_instance.load_balancer.id
  }
}
