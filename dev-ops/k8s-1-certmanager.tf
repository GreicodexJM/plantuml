###############################################################################
# 2. cert-manager (via Helm)
###############################################################################
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.13.0"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = true
  }
    # These settings make Terraform wait for the Helm release 
  # to reach a 'Deployed' status, but it might still race the CRD registration.
  wait          = true
  wait_for_jobs = true
  timeout       = 300
}

resource "null_resource" "wait_for_crds" {
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = <<-EOT
      #!/usr/bin/env bash
      set -e

      echo "Waiting for ClusterIssuer CRD to be registered..."
      for i in {1..30}; do
        if kubectl get crd clusterissuers.cert-manager.io >/dev/null 2>&1; then
          echo "ClusterIssuer CRD found!"
          exit 0
        fi
        sleep 2
      done

      echo "ERROR: clusterissuers.cert-manager.io was not found after 60 seconds."
      exit 1
    EOT
  }
}
