variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "allowed_ip_range" {
  type        = string
  description = "The IP range allowed to access the external Load Balancer"
  default     = "0.0.0.0/0" # CHANGE THIS to your specific IP range (e.g., "203.0.113.50/32") for security
}