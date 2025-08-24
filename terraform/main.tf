# =========================
# VPC & Subnets
# =========================
resource "aws_vpc" "devops_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "devops-vpc" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "af-south-1a"
  tags = { Name = "devops-public-subnet" }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.devops_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "af-south-1a"
  tags = { Name = "devops-private-subnet" }
}

# =========================
# Internet Gateway & Route Table
# =========================
resource "aws_internet_gateway" "devops_igw" {
  vpc_id = aws_vpc.devops_vpc.id
  tags   = { Name = "devops-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.devops_vpc.id
  tags   = { Name = "devops-public-rt" }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.devops_igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# =========================
# Security Groups
# =========================
# EC2 Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-ssh-sg"
  description = "Allow SSH and app traffic"
  vpc_id      = aws_vpc.devops_vpc.id  

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App port 5000"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ec2-ssh-sg" }
}

# ECS Security Group
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Allow HTTP and app traffic to ECS tasks"
  vpc_id      = aws_vpc.devops_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App port 5000"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ecs-sg" }
}

# =========================
# EC2 Instance & IAM
# =========================
resource "aws_iam_role" "ec2_cw_role" {
  name = "EC2-CloudWatch-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
         Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_cw_attach" {
  role       = aws_iam_role.ec2_cw_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_cw_profile" {
  name = "ec2-cloudwatch-profile"
  role = aws_iam_role.ec2_cw_role.name
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ec2_log_group" {
  name              = "/ec2/devops-app"
  retention_in_days = 7
  tags = { Name = "ec2-logs" }
}

# CloudWatch Agent Configuration in SSM
resource "aws_ssm_parameter" "cw_agent_config" {
  name  = "/ec2/devops-app-cw-config"
  type  = "String"
  value = jsonencode({
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path      = "/var/log/syslog"  # Change this if your app writes to another path
              log_group_name = aws_cloudwatch_log_group.ec2_log_group.name
              log_stream_name = "ec2-app-log-stream"
            }
          ]
        }
      }
    }
  })
}

resource "aws_instance" "dev_ec3" {
  ami                    = "ami-0ff0a42f151847ac7"
  instance_type          = "t3.micro"
  key_name               = "devops3-key"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_cw_profile.name

  
}

# =========================
# ECS Cluster & Fargate
# =========================
resource "aws_ecs_cluster" "devops_cluster" {
  name = "devops-cluster"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/devops-task"
  retention_in_days = 7
  tags = { Name = "devops-task-logs" }
}

resource "aws_ecs_task_definition" "devops_task" {
  family                   = "devops-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = "myapp"
    image     = var.ecs_app_image
    essential = true
    portMappings = [{ containerPort = 5000, hostPort = 5000 }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
        "awslogs-region"        = "af-south-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "devops_service" {
  name            = "devops-service"
  cluster         = aws_ecs_cluster.devops_cluster.id
  task_definition = aws_ecs_task_definition.devops_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.public_subnet.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_task_execution_attach]
}

