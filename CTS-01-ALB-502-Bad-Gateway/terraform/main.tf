# terraform/main.tf

provider "aws" {
  region = "ap-southeast-1"
}

# Base Network
resource "aws_vpc" "chaos_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "cts-01-chaos-vpc" }
}

# Public Ingress Subnets
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.chaos_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
  tags              = { Name = "cts-01-public-subnet-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.chaos_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"
  tags              = { Name = "cts-01-public-subnet-b" }
}

# Gateways & Routing
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.chaos_vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.chaos_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "pub_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# External Firewall: ALB Security Group
resource "aws_security_group" "alb_sg" {
  name   = "cts-01-alb-sg"
  vpc_id = aws_vpc.chaos_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Layer-7 Application Load Balancer
resource "aws_lb" "external_alb" {
  name               = "cts-01-routing-proxy"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

# Target Group Management
resource "aws_lb_target_group" "app_tg" {
  name     = "cts-01-target-group"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.chaos_vpc.id

  health_check {
    path                = "/"
    port                = "5000"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 5
  }
}

resource "aws_lb_listener" "http_ingress" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"

    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# 7. COMPUTE INTERIOR FIREWALL (EC2)
resource "aws_security_group" "instance_sg" {
  name   = "cts-01-instance-sg"
  vpc_id = aws_vpc.chaos_vpc.id

  # 🔒 PORT 22 IS REMOVED COMPLETELY HERE FOR BEST PRACTICE SECURITY

  # 🌐 CRUCIAL: This opens the web pipe so the ALB can talk to your app
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # <-- This links to your ALB security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Target Server Node

# 8. THE TARGET SERVER BLOCK
resource "aws_instance" "broken_target" {
  ami                         = "ami-01811d4912b4ccb26" 
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true 
  key_name                    = "postgres-lab-key" 

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              docker run -d -p 5000:80 --name production-web-target nginx
              EOF

  tags = { Name = "cts-01-broken-compute-node" }
}

resource "aws_lb_target_group_attachment" "attach_node" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.broken_target.id
  port             = 5000
}

output "alb_incident_url" {
  value = "http://${aws_lb.external_alb.dns_name}"

}