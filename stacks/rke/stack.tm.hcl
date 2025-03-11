stack {
  tags  = ["rke"]
  after = ["tag:bootstrap"]
  id    = "c44c187a-a68c-426c-a2ee-5bb79b8b3d92"
}

output "api_server_url" {
  backend   = "default"
  sensitive = true
  value     = rke_cluster.nexus.api_server_url
}

output "client_cert" {
  backend   = "default"
  sensitive = true
  value     = rke_cluster.nexus.client_cert
}

output "client_key" {
  backend   = "default"
  sensitive = true
  value     = rke_cluster.nexus.client_key
}

output "ca_crt" {
  backend   = "default"
  sensitive = true
  value     = rke_cluster.nexus.ca_crt
}
