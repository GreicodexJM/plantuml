###############################################################################
# Install Kubernetes Dashboard via Helm
###############################################################################
resource "helm_release" "kubernetes_dashboard" {
  name             = "kubernetes-dashboard"
  repository       = "https://kubernetes.github.io/dashboard/"
  chart            = "kubernetes-dashboard"
  version          = "5.11.0"
  namespace        = "kubernetes-dashboard"
  create_namespace = true

  # Example: depends_on if you are installing Ingress/Cert-Manager via Terraform
  # depends_on = [
  #   helm_release.nginx_ingress,
  #   helm_release.cert_manager
  # ]

  dynamic "set" {
    for_each = local.kubedashboard_set_list
    content {
      name  = set.value.name
      value = set.value.value
    }
  }
  depends_on = [
    helm_release.cert_manager,
    helm_release.nginx_ingress
  ]
}