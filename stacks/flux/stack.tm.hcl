stack {
  tags  = ["flux"]
  after = ["tag:rke"]
  id    = "1bb2e6f2-c16c-4573-8f47-78651669003c"
}

input "rke_api_server_url" {
  backend       = "default"
  from_stack_id = "c44c187a-a68c-426c-a2ee-5bb79b8b3d92"
  value         = outputs.api_server_url.value
  mock          = "https://example.com"
}

input "rke_client_cert" {
  backend       = "default"
  from_stack_id = "c44c187a-a68c-426c-a2ee-5bb79b8b3d92"
  value         = outputs.client_cert.value
  mock          = "MOCK"
}

input "rke_client_key" {
  backend       = "default"
  from_stack_id = "c44c187a-a68c-426c-a2ee-5bb79b8b3d92"
  value         = outputs.client_key.value
  mock          = "MOCK"
}

input "rke_ca_crt" {
  backend       = "default"
  from_stack_id = "c44c187a-a68c-426c-a2ee-5bb79b8b3d92"
  value         = outputs.ca_crt.value
  mock          = "MOCK"
}
