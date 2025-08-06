###############################################################################
# Outputs (Optional)
###############################################################################
output "ingress_nginx_info" {
  description = "Information about the NGINX ingress release."
  value       = helm_release.nginx_ingress
  sensitive   = true
}

output "cert_manager_info" {
  description = "Information about the cert-manager release."
  value       = helm_release.cert_manager
  sensitive   = true
}
