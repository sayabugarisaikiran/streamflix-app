# ================================================================
#  StreamFlix — EC2 + ALB + Route 53 Lab
#
#  This is the HANDS-ON lab config that:
#    1. Launches an EC2 with the StreamFlix app (nginx)
#    2. Creates an AMI from it (for 2nd instance)
#    3. Creates an ALB with both instances
#    4. Maps Route 53 records: A, CNAME, ALIAS
#
#  Usage:
#    cd terraform/ec2
#    terraform init
#    terraform plan
#    terraform apply
#
#  IMPORTANT: Destroy after lab to avoid charges!
#    terraform destroy
# ================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ==========================================
#  VARIABLES
# ==========================================
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (t2.micro for free tier)"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
}

variable "domain_name" {
  description = "Your Route 53 registered domain (e.g., mydomain.com). Leave empty to skip DNS."
  type        = string
  default     = ""
}

# ==========================================
#  DATA SOURCES
# ==========================================

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Route 53 zone (only if domain provided)
data "aws_route53_zone" "main" {
  count        = var.domain_name != "" ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

# ==========================================
#  NETWORKING
# ==========================================

resource "aws_vpc" "lab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "streamflix-lab-vpc", Project = "StreamFlix-Lab" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "streamflix-public-${count.index + 1}", Project = "StreamFlix-Lab" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "streamflix-lab-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
  tags = { Name = "streamflix-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Security Group: EC2 Instances ──
resource "aws_security_group" "ec2_sg" {
  name        = "streamflix-ec2-sg"
  description = "Allow HTTP from ALB and SSH from anywhere"
  vpc_id      = aws_vpc.lab.id

  # HTTP from ALB security group
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # SSH from anywhere (for lab purposes — restrict in production!)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow direct HTTP for Step 1 (before ALB)
  ingress {
    description = "Direct HTTP (for initial A-record demo)"
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

  tags = { Name = "streamflix-ec2-sg" }
}

# ── Security Group: ALB ──
resource "aws_security_group" "alb_sg" {
  name        = "streamflix-alb-sg"
  description = "Allow HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "streamflix-alb-sg" }
}


# ==========================================
#  EC2 INSTANCE 1 (Primary)
# ==========================================

resource "aws_instance" "web_1" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name    = "StreamFlix-Web-1"
    Project = "StreamFlix-Lab"
    Role    = "Primary"
  }
}

# ==========================================
#  EC2 INSTANCE 2 (From same AMI — in different AZ)
# ==========================================

resource "aws_instance" "web_2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public[1].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name    = "StreamFlix-Web-2"
    Project = "StreamFlix-Lab"
    Role    = "Secondary"
  }
}


# ==========================================
#  APPLICATION LOAD BALANCER
# ==========================================

resource "aws_lb" "main" {
  name               = "streamflix-lab-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = { Name = "streamflix-lab-alb", Project = "StreamFlix-Lab" }
}

resource "aws_lb_target_group" "web" {
  name     = "streamflix-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lab.id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
    matcher             = "200"
  }

  tags = { Project = "StreamFlix-Lab" }
}

# Register both instances as targets
resource "aws_lb_target_group_attachment" "web_1" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_2" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_2.id
  port             = 80
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}


# ==========================================
#  ROUTE 53 DNS RECORDS (only if domain provided)
# ==========================================

# Demo 1: A Record — IP → DNS (point to EC2 instance 1)
resource "aws_route53_record" "a_record_ec2" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "server1.${var.domain_name}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.web_1.public_ip]
}

# Demo 2: ALIAS Record — DNS → ALB (the correct way)
resource "aws_route53_record" "alias_to_alb" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Demo 3: CNAME Record — DNS → DNS
resource "aws_route53_record" "cname_demo" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = ["app.${var.domain_name}"]
}


# ==========================================
#  OUTPUTS
# ==========================================

output "ec2_instance_1_public_ip" {
  description = "Public IP of Instance 1 — use this for A Record demo"
  value       = aws_instance.web_1.public_ip
}

output "ec2_instance_2_public_ip" {
  description = "Public IP of Instance 2"
  value       = aws_instance.web_2.public_ip
}

output "ec2_instance_1_id" {
  value = aws_instance.web_1.id
}

output "ec2_instance_2_id" {
  value = aws_instance.web_2.id
}

output "alb_dns_name" {
  description = "ALB DNS name — students should see this in the browser"
  value       = aws_lb.main.dns_name
}

output "app_url_direct_ip" {
  description = "Direct access via IP (before DNS)"
  value       = "http://${aws_instance.web_1.public_ip}"
}

output "app_url_alb" {
  description = "Access via ALB DNS (load balanced)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "dns_records_created" {
  description = "Route 53 records created"
  value = var.domain_name != "" ? {
    a_record = "server1.${var.domain_name} → ${aws_instance.web_1.public_ip}"
    alias    = "app.${var.domain_name} → ${aws_lb.main.dns_name}"
    cname    = "www.${var.domain_name} → app.${var.domain_name}"
  } : "No domain configured — skip DNS demos"
}

output "lab_instructions" {
  description = "What to show students"
  value       = <<-EOT

  ╔═══════════════════════════════════════════════════════════════╗
  ║              StreamFlix EC2 + ALB Lab                        ║
  ╠═══════════════════════════════════════════════════════════════╣
  ║                                                               ║
  ║  STEP 1: Visit Instance 1 directly                            ║
  ║    http://${aws_instance.web_1.public_ip}                     ║
  ║    → Notice the green banner: Instance ID + AZ                ║
  ║                                                               ║
  ║  STEP 2: Visit Instance 2 directly                            ║
  ║    http://${aws_instance.web_2.public_ip}                     ║
  ║    → Notice DIFFERENT Instance ID + DIFFERENT AZ              ║
  ║                                                               ║
  ║  STEP 3: Visit via ALB (load balanced)                        ║
  ║    http://${aws_lb.main.dns_name}                             ║
  ║    → Refresh multiple times!                                  ║
  ║    → Watch the Instance ID CHANGE = load balancing working!   ║
  ║                                                               ║
  ║  STEP 4: Check health (ALB health check endpoint)             ║
  ║    curl http://${aws_lb.main.dns_name}/health                 ║
  ║                                                               ║
  ╚═══════════════════════════════════════════════════════════════╝
  EOT
}
