terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 Remote Backend Configuration
  backend "s3" {
    bucket  = "rpavani-terraform-prac" # Replace with your existing bucket name
    key     = "prod/terraform.tfstate"
    region  = "ap-south-1" # Replace with your bucket's region
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}