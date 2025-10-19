path "syst-2374/*" {
  capabilities = ["read", "list"]
}

path "syst-2374/" {
  capabilities = ["list", "subscribe"]
  subscribe_event_types = ["*"]
}

path "sys/events/subscribe/*" {
  capabilities = ["read"]
}
