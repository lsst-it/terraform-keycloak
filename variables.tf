variable "bind_pass" {
  description = "Bind password for LDAP"
  sensitive = true
}

variable "keycloak_url" {
  description = "URL for Keycloak"
  default = "https://keycloak.ruka.dev.lsst.org"
}

variable "keycloak_client_secret" {
  description = "Client secret for Keycloak"
  sensitive = true
}

variable "grafana_client_secret" {
  description = "Client secret for Grafana"
  sensitive = true
}

variable "root_url" {
  description = "Root URL for the application"
  default = "https://grafana.ruka.dev.lsst.org"
}

variable "ldap_url" {
  description = "LDAP URL"
  default = "ldap://ipa.lsst.org:389"
}
