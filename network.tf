### Domain names
resource "aws_route53_zone" "eramba_primary_zone" {
  name = var.ERAMBA_DOMAIN
}
resource "aws_route53_record" "grc-it" {
  zone_id = aws_route53_zone.eramba_primary_zone.zone_id
  name    = "${var.ERAMBA_SUBDOMAIN}.${var.ERAMBA_DOMAIN}"
  type    = "A"
  ttl     = "10"
  records = [aws_instance.eramba_web.public_ip]
}

### Security Groups
resource "aws_security_group" "web_ports" {
  vpc_id      = aws_vpc.SecurityTeam_PoC-VPC.id
  name        = "allow_web_listening"
  description = "Allow HTTP/HTTPS inbound"

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

  tags = {
    Name = "allow_web_listening"
  }
}
resource "aws_security_group" "ssh" {
  vpc_id      = aws_vpc.SecurityTeam_PoC-VPC.id
  name        = "allow_ssh_listening"
  description = "Allow SSH inbound"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_listening"
  }
}
resource "aws_security_group" "mariadb" {
  vpc_id      = aws_vpc.SecurityTeam_PoC-VPC.id
  name        = "allow_mariadb"
  description = "Allow access to the rDBMS instance"

  ingress {
    description     = "MariaDB"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eramba.id]
  }

  tags = {
    Name = "allow_mariadb"
  }
}
resource "aws_security_group" "egress_all" {
  vpc_id      = aws_vpc.SecurityTeam_PoC-VPC.id
  name        = "allow_outbound_traffic"
  description = "Allow outbound traffic"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_outbound_traffic"
  }
}
resource "aws_security_group" "eramba" {
  vpc_id = aws_vpc.SecurityTeam_PoC-VPC.id
}

### VPC
resource "aws_vpc" "SecurityTeam_PoC-VPC" {
  cidr_block           = "10.156.100.0/24"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"

  tags = {
    Name = "SecurityTeam_PoC-VPC"
  }
}

# Subnets
resource "aws_subnet" "security-public-az1" {
  vpc_id                  = aws_vpc.SecurityTeam_PoC-VPC.id
  cidr_block              = "10.156.100.0/26"
  map_public_ip_on_launch = "true"
  availability_zone       = "eu-central-1a"

  tags = {
    Name = "security-public-az1"
  }
}
resource "aws_subnet" "security-private-az1" {
  vpc_id                  = aws_vpc.SecurityTeam_PoC-VPC.id
  cidr_block              = "10.156.100.64/26"
  map_public_ip_on_launch = "false"
  availability_zone       = "eu-central-1a"

  tags = {
    Name = "security-private-az1"
  }
}
resource "aws_subnet" "security-public-az2" {
  vpc_id                  = aws_vpc.SecurityTeam_PoC-VPC.id
  cidr_block              = "10.156.100.128/26"
  map_public_ip_on_launch = "true"
  availability_zone       = "eu-central-1b"

  tags = {
    Name = "security-public-az2"
  }
}
resource "aws_subnet" "security-private-az2" {
  vpc_id                  = aws_vpc.SecurityTeam_PoC-VPC.id
  cidr_block              = "10.156.100.192/26"
  map_public_ip_on_launch = "false"
  availability_zone       = "eu-central-1b"

  tags = {
    Name = "security-private-az2"
  }
}

# Internet GW
resource "aws_internet_gateway" "SecurityTeam_PoC-GW" {
  vpc_id = aws_vpc.SecurityTeam_PoC-VPC.id

  tags = {
    Name = "SecurityTeam_PoC-GW"
  }
}

# Route table
resource "aws_route_table" "SecurityTeam_PoC-RT" {
  vpc_id = aws_vpc.SecurityTeam_PoC-VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.SecurityTeam_PoC-GW.id
  }

  tags = {
    Name = "SecurityTeam_PoC-RT-Internet"
  }
}
resource "aws_route_table_association" "security-public-az1-RT" {
  subnet_id      = aws_subnet.security-public-az1.id
  route_table_id = aws_route_table.SecurityTeam_PoC-RT.id
}
resource "aws_route_table_association" "security-public-az2-RT" {
  subnet_id      = aws_subnet.security-public-az2.id
  route_table_id = aws_route_table.SecurityTeam_PoC-RT.id
}