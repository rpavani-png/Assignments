output "load_balancer_dns" {
  value       = module.compute.lb_dns_name
  description = "Access the High Availability website via this URL"
}