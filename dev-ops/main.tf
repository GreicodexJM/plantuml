###############################################################################
# variables.tf
###############################################################################

# DigitalOcean API token (required)
variable "do_token" {
  type        = string
  description = "DigitalOcean API token"
  sensitive   = true
}


# Name of the existing DigitalOcean Kubernetes (DOKS) cluster
variable "cluster_name" {
  type        = string
  description = "Name of the DOKS/EKS/AKS cluster to configure providers for"
  default     = "my-k8s-cluster"
}

# (Optional) If you’re creating the cluster with Terraform, 
# you might have variables for region, node size, etc.:
#
variable "cloud_region" {
  type        = string
  description = "DigitalOcean/AWS region for the cluster"
  default     = "us-west-2"
}
variable "resource_group_name" {
  type        = string
  description = "Azure resource group for the cluster"
  default     = "azurerm"
}
#
# variable "do_node_size" {
#   type        = string
#   description = "Droplet size for the worker nodes"
#   default     = "s-2vcpu-4gb"
# }

variable "domain_name" {
  type        = string
  description = "Domain name used to load the services"
  default     = "local"
}
###############################################################################
# Merged "common vs. domain-specific" Helm settings for Kubernetes Dashboard
###############################################################################

locals {
  # 1) Common / base settings for the chart
  dashboard_base_set_list = [
    {
      name  = "service.type"
      value = "ClusterIP"
    }
    # Add any other settings that are always the same
  ]

  # 2) Overrides if domain_name == "local"
  #    => Disable auth, skip Ingress
  local_mode_overrides = [
    {
      # Turn off Ingress entirely
      name  = "ingress.enabled"
      value = "false"
    },
    {
      # Enable insecure login
      name  = "extraArgs[0]"
      value = "--enable-insecure-login"
    },
    {
      # Skip the login screen entirely
      name  = "extraArgs[1]"
      value = "--enable-skip-login"
    }
  ]

  # 3) Overrides if domain_name != "local"
  #    => Enable Ingress + TLS with cert-manager
  ingress_mode_overrides = [
    {
      name  = "ingress.enabled"
      value = "true"
    },
    {
      name = "ingress.annotations"
      # Ties the Ingress to NGINX + cert-manager (staging)
      value = jsonencode({
        "kubernetes.io/ingress.class"    = "nginx"
        "cert-manager.io/cluster-issuer" = "letsencrypt-staging"
      })
    },
    {
      # Use the domain_name for the host
      name  = "ingress.hosts[0].host"
      value = var.domain_name
    },
    {
      name  = "ingress.hosts[0].paths[0].path"
      value = "/"
    },
    {
      name  = "ingress.hosts[0].paths[0].pathType"
      value = "Prefix"
    },
    {
      # Add TLS config
      name  = "ingress.tls[0].hosts[0]"
      value = var.domain_name
    },
    {
      name  = "ingress.tls[0].secretName"
      value = "dashboard-tls"
    }
  ]

  # Merge base settings with either local or ingress overrides
  # Ternary: if domain_name == "local" => base + local_mode, else base + ingress_mode
  kubedashboard_set_list = var.domain_name == "local" ? concat(local.dashboard_base_set_list, local.local_mode_overrides) : concat(local.dashboard_base_set_list, local.ingress_mode_overrides)
}

