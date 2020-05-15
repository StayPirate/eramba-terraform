# Print EC2 public IP
output "Eramba-IP" {
  value = aws_instance.eramba_web.public_ip
}

# Print resource URI
output "S3_eramba-src" {
  value = "https://${aws_s3_bucket.eramba-src.bucket_domain_name}/${aws_s3_bucket_object.eramba-enterprise-src_upload.id}"
}

# Print MariaDB domain name and port
output "MariaDB" {
  value = aws_db_instance.eramba_db.endpoint
}