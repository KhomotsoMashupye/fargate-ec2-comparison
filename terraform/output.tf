output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.dev_ec3.public_ip
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.devops_cluster.name
}


output "ec2_cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.ec2_log_group.name
}

output "ecs_cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.ecs_log_group.name
}

