// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

output "api_server_url" {
  value     = rke_cluster.nexus.api_server_url
  sensitive = true
}
output "client_cert" {
  value     = rke_cluster.nexus.client_cert
  sensitive = true
}
output "client_key" {
  value     = rke_cluster.nexus.client_key
  sensitive = true
}
output "ca_crt" {
  value     = rke_cluster.nexus.ca_crt
  sensitive = true
}
