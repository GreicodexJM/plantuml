###############################################################################
# 3. Let’s Encrypt Staging ClusterIssuer
#    - For local dev, you typically do "staging" to avoid rate limits.
###############################################################################
resource "kubernetes_manifest" "letsencrypt_staging_issuer" {
  depends_on = [
     null_resource.wait_for_crds
  ]
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
    }
    spec = {
      acme = {
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = "your-email@example.com" # CHANGE to your real email
        privateKeySecretRef = {
          name = "letsencrypt-staging-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }

}

###############################################################################
# (Optional) 4. Self-signed ClusterIssuer
# Uncomment if you prefer self-signed certs for purely local dev
###############################################################################

resource "kubernetes_manifest" "selfsigned_issuer" {
  depends_on = [
     null_resource.wait_for_crds
  ]
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned-clusterissuer"
    }
    spec = {
      selfSigned = {}
    }
  }

}

