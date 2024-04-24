// Mapper for Paralus IDP
// copied from https://github.com/paralus/paralus/blob/d705c16ced3f5e0831b19972de70b0d3229391c0/_kratos/oidc-mappers/keycloak.jsonnet
//
// IdP Type      : Generic
// Client ID     : keycloak
// Client Secret : lotsoflettersandnumbers
// Scopes        : email, profile, openid, groups
// Issuer Url    : https://keycloak.example.com/realms/paralus
// Auth Url      : https://keycloak.example.com/realms/paralus/protocol/openid-connect/auth
// Token Url     : https://keycloak.example.com/realms/paralus/protocol/openid-connect/token
// Callback Url  : https://console.paralus.example.com/self-service/methods/oidc/callback/keycloak

local claims = {
  email_verified: false,
} + std.extVar('claims');

{
  identity: {
    traits: {
      [if 'email' in claims && claims.email_verified then 'email' else null]: claims.email,
      [if 'given_name' in claims then 'first_name' else null]: claims.given_name,
      [if 'family_name' in claims then 'last_name' else null]: claims.family_name,
      [if 'groups' in claims.raw_claims then 'idp_groups' else null]: claims.raw_claims.groups,
    },
  },
}
