###############################################################################
# 1. NGINX Ingress Controller (via Helm)
###############################################################################
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.7.1" # or whatever is current
  namespace        = "ingress-nginx"
  create_namespace = true

  # Example: if you want to override the service type
  # set {
  #   name  = "controller.service.type"
  #   value = "NodePort"
  # }
  depends_on = [
    helm_release.cert_manager
  ]
}