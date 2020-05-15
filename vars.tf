# AWS authentication
variable "AWS_ACCESS_KEY_ID" {}
variable "AWS_SECRET_ACCESS_KEY" {}
# AWS region
variable "AWS_REGION" {
  type    = string
  default = "eu-central-1"
}

### EC2
# AMI mapped to GNU/Linux distribution name
variable "DISTRO" {
  type    = string
  default = "AmazonLinux"
}
variable "AMIS" {
  type = map(string)
  default = {
    AmazonLinux = "ami-076431be05aaf8080"
    SLES15SP1   = "ami-0ca9e27238973cf36"
    SLES12SP5   = "ami-0c7e57d749929fcfe"
  }
}
# Name of the defaut user created through cloud-init
variable "DEFAULT_USER" {
  type    = string
  default = "ops"
}
# SSH Public key to access the EC2 instance
variable "SSH_PUBKEY" {
  type = string
}
variable "SSH_KEY_NAME" {
  type    = string
  default = "sshkey"
}
# EC2 Instance type
variable "ERAMBA_WEB_INSTANCE_TYPE" {
  type    = string
  default = "t2.micro"
}

# rDBMS
# DB Instance type
variable "ERAMBA_DB_INSTANCE_TYPE" {
  type    = string
  default = "db.t2.small"
}
# Database username
variable "DB_USERNAME" {
  type    = string
  default = "eramba"
}
# Databse name
variable "DB_DATABASE" {
  type    = string
  default = "eramba"
}
# Database schema version. It is included into the Eramba source-code.
variable "DB_SCHEMA_VERS" {
  type    = string
  default = "e2.12.0"
}

# Domains Name
variable "ERAMBA_DOMAIN" {
  type    = string
  default = "localhost"
}
# In case you want to use a subdomain to reach the web-site, just specify the subdomain.
# For instance to use eramba.company.tld, set this variable as 'eramba' and the variable ERAMBA_DOMAIN as 'company.tld'
# If a subdomain is not required, leave this variable empty.
variable "ERAMBA_SUBDOMAIN" {
  type    = string
  default = ""
}