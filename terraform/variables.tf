variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}

variable "public_subnet_cidr" {
  default     = "10.0.1.0/24"
  description = "Public subnet CIDR block"
}

variable "private_subnet_cidr" {
  default     = "10.0.2.0/24"
  description = "Private subnet CIDR block"
}


variable "ec2_key_name" {
  description = "Key pair name for EC2 instance"
  default     = "devops3-key"
}

variable "ecs_app_image" {
  description = "ECR image URI for the ECS task"
  type        = string
  default     = "522237065210.dkr.ecr.af-south-1.amazonaws.com/myapp-latestrepo:latest"  
}
