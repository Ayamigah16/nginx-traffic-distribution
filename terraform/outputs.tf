# Output Values - Display After Terraform Apply

# Load Balancer Outputs
output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer (Elastic IP)"
  value       = aws_eip.load_balancer.public_ip
}

output "load_balancer_public_dns" {
  description = "Public DNS of the load balancer"
  value       = aws_eip.load_balancer.public_dns
}

output "load_balancer_instance_id" {
  description = "Instance ID of the load balancer"
  value       = aws_instance.load_balancer.id
}

# Backend Server 1 Outputs
output "server1_public_ip" {
  description = "Public IP address of backend server 1"
  value       = aws_instance.backend_server1.public_ip
}

output "server1_private_ip" {
  description = "Private IP address of backend server 1"
  value       = aws_instance.backend_server1.private_ip
}

output "server1_instance_id" {
  description = "Instance ID of backend server 1"
  value       = aws_instance.backend_server1.id
}

# Backend Server 2 Outputs
output "server2_public_ip" {
  description = "Public IP address of backend server 2"
  value       = aws_instance.backend_server2.public_ip
}

output "server2_private_ip" {
  description = "Private IP address of backend server 2"
  value       = aws_instance.backend_server2.private_ip
}

output "server2_instance_id" {
  description = "Instance ID of backend server 2"
  value       = aws_instance.backend_server2.id
}

# Network Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

# Security Group Outputs
output "lb_security_group_id" {
  description = "Security group ID for load balancer"
  value       = aws_security_group.lb_sg.id
}

output "backend_security_group_id" {
  description = "Security group ID for backend servers"
  value       = aws_security_group.backend_sg.id
}

# Access Information
output "ssh_command_load_balancer" {
  description = "SSH command to connect to load balancer"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.load_balancer.public_ip}"
}

output "ssh_command_server1" {
  description = "SSH command to connect to backend server 1"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.backend_server1.public_ip}"
}

output "ssh_command_server2" {
  description = "SSH command to connect to backend server 2"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.backend_server2.public_ip}"
}

# URLs
output "load_balancer_url" {
  description = "Load balancer URL"
  value       = "http://${aws_instance.load_balancer.public_ip}"
}

output "server1_url" {
  description = "Backend server 1 URL"
  value       = "http://${aws_instance.backend_server1.public_ip}:8081"
}

output "server2_url" {
  description = "Backend server 2 URL"
  value       = "http://${aws_instance.backend_server2.public_ip}:8082"
}

# Test Command
output "test_load_balancer" {
  description = "Command to test load balancer distribution"
  value       = "for i in {1..10}; do curl -s http://${aws_instance.load_balancer.public_ip}/server-status | grep server; sleep 1; done"
}

# Summary
output "deployment_summary" {
  description = "Deployment summary"
  value = {
    region              = var.aws_region
    project_name        = var.project_name
    environment         = var.environment
    load_balancer_ip    = aws_instance.load_balancer.public_ip
    server1_ip          = aws_instance.backend_server1.public_ip
    server2_ip          = aws_instance.backend_server2.public_ip
    algorithm           = var.lb_algorithm
    instance_type       = var.instance_type
  }
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost (USD) - rough estimate"
  value       = "~$${3 * (var.instance_type == "t2.micro" ? 7.50 : var.instance_type == "t2.small" ? 15 : 30)} (3 instances, excl. data transfer)"
}

# Next Steps
output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT
    
    ✅ Infrastructure deployed successfully!
    
    🌐 Access your services:
       Load Balancer: http://${aws_instance.load_balancer.public_ip}
       Server 1:      http://${aws_instance.backend_server1.public_ip}:8081
       Server 2:      http://${aws_instance.backend_server2.public_ip}:8082
    
    🔐 SSH access:
       ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.load_balancer.public_ip}
    
    🧪 Test load balancing:
       for i in {1..10}; do curl http://${aws_instance.load_balancer.public_ip}; done
    
    📊 Monitor logs:
       ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.load_balancer.public_ip}
       sudo tail -f /var/log/nginx/access.log
    
    🛑 When done, destroy resources:
       terraform destroy
  EOT
}
