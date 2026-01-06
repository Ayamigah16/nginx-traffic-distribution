# Input Variables for Terraform Configuration

# AWS Configuration
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "nginx-lb-tutorial"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "DevOps-Team"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type for all servers"
  type        = string
  default     = "t3.micro"  # Free tier eligible (750 hours/month for first 12 months)
  
  validation {
    condition     = can(regex("^t[2-3]\\.(micro|small|medium)", var.instance_type))
    error_message = "Instance type must be a valid t2 or t3 instance type."
  }
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (leave empty for auto-detection of latest Ubuntu)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "AWS EC2 key pair name for SSH access"
  type        = string
  
  validation {
    condition     = length(var.key_name) > 0
    error_message = "Key name must be specified for SSH access."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 8
}

# Security Configuration
variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH into instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Change this in production!
}

variable "allowed_http_cidr" {
  description = "CIDR blocks allowed to access HTTP services"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = false  # Set to true for production
}

variable "enable_termination_protection" {
  description = "Enable EC2 termination protection"
  type        = bool
  default     = false  # Set to true for production
}

# Load Balancing Configuration
variable "lb_algorithm" {
  description = "Load balancing algorithm (round_robin, least_conn, ip_hash, weighted)"
  type        = string
  default     = "round_robin"
  
  validation {
    condition     = contains(["round_robin", "least_conn", "ip_hash", "weighted"], var.lb_algorithm)
    error_message = "Algorithm must be one of: round_robin, least_conn, ip_hash, weighted."
  }
}

variable "server1_weight" {
  description = "Weight for backend server 1 (used with weighted algorithm)"
  type        = number
  default     = 3
}

variable "server2_weight" {
  description = "Weight for backend server 2 (used with weighted algorithm)"
  type        = number
  default     = 1
}

# Feature Flags
variable "deploy_alb" {
  description = "Deploy AWS Application Load Balancer instead of software LB"
  type        = bool
  default     = false
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for backend servers"
  type        = bool
  default     = false
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Backend Configuration
variable "backend_server_count" {
  description = "Number of backend servers to deploy"
  type        = number
  default     = 2
  
  validation {
    condition     = var.backend_server_count >= 2 && var.backend_server_count <= 10
    error_message = "Backend server count must be between 2 and 10."
  }
}
