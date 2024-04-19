terraform {
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.4.0"
    }
  }
}

provider "keycloak" {
  client_id     = "tofu"
  client_secret = var.keycloak_client_secret
  url           = var.keycloak_url
}

resource "keycloak_realm" "realm" {
  realm                       = "master"
  enabled                     = true
  default_signature_algorithm = "RS256"
  display_name                = "Keycloak"
  display_name_html           = "<div class=\"kc-logo-text\"><span>Keycloak</span></div>"

  sso_session_idle_timeout    = "${7 * 24}h0m0s"
  sso_session_max_lifespan    = "${7 * 24}h0m0s"
  client_session_idle_timeout = "${4 * 24}h0m0s"
  client_session_max_lifespan = "${5 * 24}h0m0s"
  access_token_lifespan       = "2h0m0s"
}

resource "keycloak_realm_events" "realm_events" {
  realm_id = keycloak_realm.realm.id

  events_enabled    = true
  events_expiration = 86400

  admin_events_enabled         = true
  admin_events_details_enabled = true

  events_listeners = [
    "jboss-logging",
  ]
}

resource "keycloak_ldap_user_federation" "ldap_user_federation" {
  name     = "ipa.lsst.org"
  realm_id = keycloak_realm.realm.id
  enabled  = true

  vendor                  = "RHDS"
  connection_url          = var.ldap_url
  use_truststore_spi      = "ALWAYS"
  bind_dn                 = "uid=svc_keycloak,cn=users,cn=accounts,dc=lsst,dc=cloud"
  bind_credential         = var.bind_pass
  users_dn                = "cn=users,cn=accounts,dc=lsst,dc=cloud"
  username_ldap_attribute = "uid"
  rdn_ldap_attribute      = "uid"
  uuid_ldap_attribute     = "ipaUniqueID"
  user_object_classes = [
    "inetOrgPerson",
    "organizationalPerson",
  ]

  pagination          = false # XXX 389ds/ipa support this?
  batch_size_for_sync = null
  full_sync_period    = "86400"
  trust_email         = true
}

resource "keycloak_ldap_group_mapper" "ldap_group_mapper" {
  realm_id                = keycloak_realm.realm.id
  ldap_user_federation_id = keycloak_ldap_user_federation.ldap_user_federation.id
  name                    = "ipa-groups"

  ldap_groups_dn            = "cn=groups,cn=accounts,dc=lsst,dc=cloud"
  group_name_ldap_attribute = "cn"
  group_object_classes = [
    "groupOfNames"
  ]
  preserve_group_inheritance     = false
  membership_attribute_type      = "DN"
  membership_ldap_attribute      = "member"
  membership_user_ldap_attribute = "uid"
  memberof_ldap_attribute        = "memberOf"
}

resource "keycloak_openid_client_scope" "groups" {
  realm_id               = keycloak_realm.realm.id
  name                   = "groups"
  description            = "When requested, this scope will map a user's group memberships to a claim"
  include_in_token_scope = true
  gui_order              = 1
}

resource "keycloak_openid_group_membership_protocol_mapper" "group_membership_mapper" {
  realm_id        = keycloak_realm.realm.id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "groups"

  full_path  = false
  claim_name = "groups"
}

resource "keycloak_openid_client" "grafana" {
  realm_id    = keycloak_realm.realm.id
  client_id   = "grafana-ruka"
  description = "All your base are belong to us"

  name    = "Grafana on ruka"
  enabled = true

  root_url = var.root_url
  base_url = var.root_url
  valid_redirect_uris = [
    "${var.root_url}/login/generic_oauth"
  ]
  admin_url = var.root_url
  web_origins = [
    var.root_url,
  ]

  standard_flow_enabled        = true
  access_type                  = "CONFIDENTIAL"
  direct_access_grants_enabled = true
  frontchannel_logout_enabled  = true

  client_secret = var.grafana_client_secret
}

resource "keycloak_openid_client_default_scopes" "client_default_scopes" {
  realm_id  = keycloak_realm.realm.id
  client_id = keycloak_openid_client.grafana.id

  default_scopes = [
    "acr",
    "email",
    keycloak_openid_client_scope.groups.name,
    "roles",
    "profile",
  ]
}

resource "keycloak_role" "grafana" {
  for_each    = toset(["admin", "editor", "viewer"])
  realm_id    = keycloak_realm.realm.id
  client_id   = keycloak_openid_client.grafana.id
  name        = each.key
  description = "grafana ${each.key}"
}
