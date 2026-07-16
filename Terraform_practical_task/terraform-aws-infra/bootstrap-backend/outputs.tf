output "backend_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "backend_region" {
  value = var.backend_region
}
