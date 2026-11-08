# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

# 1. Create a Custom VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "three-tier-vpc"
    Environment = "dev"
  }
}

# 2. Create Internet Gateway for Public Traffic
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "three-tier-igw"
  }
}

# 3. Create Public Subnets (For ALB / Presentation Tier)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = { Name = "subnet-public-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = { Name = "subnet-public-2" }
}

# 4. Create Private App Subnets (For Application Tier / Web Servers)
resource "aws_subnet" "private_app_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "ap-south-1a"

  tags = { Name = "subnet-private-app-1" }
}

resource "aws_subnet" "private_app_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "ap-south-1b"

  tags = { Name = "subnet-private-app-2" }
}

# 5. Create Private DB Subnets (For Database Tier / RDS)
resource "aws_subnet" "private_db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.30.0/24"
  availability_zone = "ap-south-1a"

  tags = { Name = "subnet-private-db-1" }
}

resource "aws_subnet" "private_db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.40.0/24"
  availability_zone = "ap-south-1b"

  tags = { Name = "subnet-private-db-2" }
}
 # 6. Create Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "three-tier-public-rt"
  }
}

# 7. Associate Public Subnet 1 with Public Route Table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# 8. Associate Public Subnet 2 with Public Route Table
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
 # 9. Allocate Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "three-tier-nat-eip"
  }
}

# 10. Create NAT Gateway in Public Subnet 1
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "three-tier-nat-gw"
  }

  depends_on = [aws_internet_gateway.gw]
}

# 11. Create Private Route Table for App Tier
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "three-tier-private-rt"
  }
}

# 12. Associate Private App Subnet 1 with Private Route Table
resource "aws_route_table_association" "private_app_1" {
  subnet_id      = aws_subnet.private_app_1.id
  route_table_id = aws_route_table.private.id
}

# 13. Associate Private App Subnet 2 with Private Route Table
resource "aws_route_table_association" "private_app_2" {
  subnet_id      = aws_subnet.private_app_2.id
  route_table_id = aws_route_table.private.id
}
 # 14. Security Group for Public ALB (Presentation Tier)
resource "aws_security_group" "alb" {
  name        = "three-tier-alb-sg"
  description = "Allow HTTP and HTTPS inbound traffic from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "three-tier-alb-sg"
  }
}

# 15. Security Group for Private App Servers (Application Tier)
resource "aws_security_group" "app" {
  name        = "three-tier-app-sg"
  description = "Allow HTTP traffic from ALB and SSH/Management if needed"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow HTTP from ALB security group"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Allow custom application port (e.g., Node.js/Python app on port 3000/8080) from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic (for NAT Gateway updates)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "three-tier-app-sg"
  }
}

# 16. Security Group for Private Database (Database Tier)
resource "aws_security_group" "db" {
  name        = "three-tier-db-sg"
  description = "Allow MySQL/PostgreSQL traffic strictly from App Tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow MySQL/Aurora from App security group"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "three-tier-db-sg"
  }
}
 # 17. Database Subnet Group (Across Private DB Subnets)
resource "aws_db_subnet_group" "default" {
  name        = "three-tier-db-subnet-group"
  subnet_ids  = [aws_subnet.private_db_1.id, aws_subnet.private_db_2.id]
  description = "Private database subnets for RDS"

  tags = {
    Name = "three-tier-db-subnet-group"
  }
}

# 18. RDS Database Instance (MySQL or PostgreSQL)
resource "aws_db_instance" "default" {
  identifier             = "three-tier-db"
  allocated_storage      = 20
  max_allocated_storage  = 100
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "appdb"
  username               = "adminuser"
  password               = "SecurePassword123!" # In production, use AWS Secrets Manager or variables
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "three-tier-database"
  }
}
 # 19. Data source to fetch the latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# 20. First EC2 Instance for Application Tier with DB Test
resource "aws_instance" "app_1" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_app_1.id
  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd mariadb105
              systemctl start httpd
              systemctl enable httpd

              DB_HOST="${aws_db_instance.default.address}"
              DB_USER="adminuser"
              DB_PASS="SecurePassword123!"

              if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" &>/dev/null; then
                DB_STATUS="Connected Successfully to RDS MySQL!"
              else
                DB_STATUS="Database Connection Failed (Check SGs or Endpoint)"
              fi

              echo "<html><body><h1>Three-Tier App Server 1</h1><p><b>DB Status:</b> $DB_STATUS</p></body></html>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "three-tier-app-instance-1"
  }
}
 # 21. Application Load Balancer Target Group
resource "aws_lb_target_group" "app" {
  name        = "three-tier-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "three-tier-tg"
  }
}

# 22. Public Application Load Balancer
resource "aws_lb" "external" {
  name               = "three-tier-public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "three-tier-public-alb"
  }
}

# 23. ALB Listener on Port 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.external.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# 24. Attach App Instance 1 to Target Group
resource "aws_lb_target_group_attachment" "app_1" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app_1.id
  port             = 80
}
 # 25. Second EC2 Instance for Application Tier with DB Test
resource "aws_instance" "app_2" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_app_2.id
  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd mariadb105
              systemctl start httpd
              systemctl enable httpd

              DB_HOST="${aws_db_instance.default.address}"
              DB_USER="adminuser"
              DB_PASS="SecurePassword123!"

              if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" &>/dev/null; then
                DB_STATUS="Connected Successfully to RDS MySQL!"
              else
                DB_STATUS="Database Connection Failed (Check SGs or Endpoint)"
              fi

              echo "<html><body><h1>Three-Tier App Server 2</h1><p><b>DB Status:</b> $DB_STATUS</p></body></html>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "three-tier-app-instance-2"
  }
}

# 26. Attach App Instance 2 to Target Group
resource "aws_lb_target_group_attachment" "app_2" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app_2.id
  port             = 80
}
 output "rds_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = aws_db_instance.default.endpoint
}