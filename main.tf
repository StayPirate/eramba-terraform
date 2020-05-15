### Providers
provider "aws" {
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
  region     = var.AWS_REGION
}
provider "cloudinit" {}

### EC2 Instance running dockerd
# This instance runs the Eramba docker container. It's an Apache+PHP dockerized service with the Eramba-enterprice source-code.
# It's meant as a temporary solution, the container will be migrated to k8s once the cluster will be ready.
resource "aws_instance" "eramba_web" {
  ami           = lookup(var.AMIS, var.DISTRO)
  instance_type = var.ERAMBA_WEB_INSTANCE_TYPE
  key_name      = aws_key_pair.ssh-key.key_name
  user_data     = data.template_cloudinit_config.deploy.rendered
  subnet_id     = aws_subnet.security-public-az1.id
  vpc_security_group_ids = [aws_security_group.web_ports.id,
    aws_security_group.ssh.id,
    aws_security_group.egress_all.id,
  aws_security_group.eramba.id]

  # Role
  iam_instance_profile = aws_iam_instance_profile.eramba_s3-instanceprofile.name

  depends_on = [
    aws_s3_bucket_object.eramba-enterprise-src_upload
  ]

  tags = {
    Name = "Eramba-web"
  }
}
# Add SSH key
resource "aws_key_pair" "ssh-key" {
  key_name   = var.SSH_KEY_NAME
  public_key = var.SSH_PUBKEY
}
# Install packages and create default user
data "template_file" "init-script" {
  template = file("scripts/init.tpl")

  vars = {
    USER = var.DEFAULT_USER
  }
}
# Configure host OS
data "template_file" "shell-script" {
  template = file("scripts/host-configuration.tpl")

  vars = {
    op_user       = var.DEFAULT_USER
    db_address    = aws_db_instance.eramba_db.address
    db_password   = random_password.eramba_db_password.result
    db_username   = var.DB_USERNAME
    db_database   = var.DB_DATABASE
    db_schema_v   = var.DB_SCHEMA_VERS
    s3_address    = aws_s3_bucket.eramba-src.id
    eramba_src    = aws_s3_bucket_object.eramba-enterprise-src_upload.id
    eramba_domain = "${var.ERAMBA_SUBDOMAIN}.${var.ERAMBA_DOMAIN}"
  }
}
data "template_cloudinit_config" "deploy" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.init-script.rendered
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.shell-script.rendered
  }
}

### S3 Bucket
# The S3 bucket is used to copy the eramba code-base to the EC2 instance.
# It cannot be downloaded from internet due the enterprice license.
resource "aws_s3_bucket" "eramba-src" {
  bucket = "eramba-webapp-src"
  acl    = "private"
  region = var.AWS_REGION

  versioning {
    enabled = true
  }

  tags = {
    Name = "eramba-src"
  }
}
# Upload the Eramba Enterprice source code
resource "aws_s3_bucket_object" "eramba-enterprise-src_upload" {
  bucket = aws_s3_bucket.eramba-src.id
  key    = "eramba_latest.tar.gz"
  source = "upload/eramba_latest.tar.gz"
  etag   = filemd5("upload/eramba_latest.tar.gz")
}
# Create a dedicated role to provide read-only access to the S3 Bucket.
# It is assumed by the EC2 instance to get the tar.gz with the source code.
resource "aws_iam_role" "eramba_s3-access" {
  name               = "eramba_s3-access"
  assume_role_policy = data.aws_iam_policy_document.eramba_s3-access-policy.json
}
resource "aws_iam_instance_profile" "eramba_s3-instanceprofile" {
  name = "eramba_s3-instanceprofile"
  role = aws_iam_role.eramba_s3-access.name
}
resource "aws_iam_role_policy" "eramba_s3-role-policy" {
  name   = "eramba_s3-role-policy"
  role   = aws_iam_role.eramba_s3-access.id
  policy = data.aws_iam_policy_document.eramba_s3-instanceprofile-policy.json
}
data "aws_iam_policy_document" "eramba_s3-access-policy" {
  version = "2012-10-17"
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"

    sid = ""
  }
}
data "aws_iam_policy_document" "eramba_s3-instanceprofile-policy" {
  version = "2012-10-17"
  statement {
    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.eramba-src.arn}",
      "${aws_s3_bucket.eramba-src.arn}/*"
    ]

    effect = "Allow"
  }
}

### Amazon RDS
# Eramba requires a MySQL comaptible rDBMS backend.
# We chose to use Amazon RDS running MariaDB.

# Database user's password automatically generated.
resource "random_password" "eramba_db_password" {
  length      = 20
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}
# MariaDB parameters set according to the Eramba guide-lines 
resource "aws_db_parameter_group" "mariadb-parameters" {
  name        = "mariadb-parameters"
  family      = "mariadb10.4"
  description = "Eramba backend parameters group"

  parameter {
    name  = "max_allowed_packet"
    value = "134217728" # 128Mb
  }

  parameter {
    name  = "innodb_lock_wait_timeout"
    value = "200"
  }

  parameter {
    name  = "sql_mode"
    value = "NO_ENGINE_SUBSTITUTION"
  }

  parameter {
    name  = "log_bin_trust_function_creators"
    value = true
  }
}
# Subnets where the service is reachable
resource "aws_db_subnet_group" "mariadb-subnet" {
  name        = "mariadb-subnet"
  description = "RDS subnet group"
  subnet_ids = [aws_subnet.security-private-az1.id,
  aws_subnet.security-private-az2.id]
}
# The MariaDB instance 
resource "aws_db_instance" "eramba_db" {
  allocated_storage       = 100 # 100 GB
  engine                  = "mariadb"
  engine_version          = "10.4.8"
  instance_class          = var.ERAMBA_DB_INSTANCE_TYPE
  identifier              = "mariadb"
  username                = var.DB_USERNAME
  name                    = var.DB_DATABASE
  password                = random_password.eramba_db_password.result
  db_subnet_group_name    = aws_db_subnet_group.mariadb-subnet.name
  parameter_group_name    = aws_db_parameter_group.mariadb-parameters.name
  multi_az                = "false"
  vpc_security_group_ids  = [aws_security_group.mariadb.id]
  storage_type            = "gp2"
  backup_retention_period = 90 # 90 Days
  skip_final_snapshot     = true

  tags = {
    Name = "Eramba_db"
  }
}