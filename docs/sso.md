# Single sign-on with Entra ID or Okta

With YadVault Pro, people can sign in with their Microsoft Entra ID or Okta account instead of a
YadVault password. The provider decides at every sign-in whether someone may use the archive and
with which role. The first admin, created in the setup wizard, always keeps a password: it is the
way in when the provider is down or misconfigured.

YadVault uses OpenID Connect: the authorization code flow with PKCE, as a confidential client with
a client secret. SAML is not supported.

## How it works

1. On the sign-in page, a person clicks **Sign in with ...** and signs in at the provider.
2. The provider sends the browser back to YadVault's redirect address with a one-time code.
   YadVault exchanges the code for an ID token and checks it (see [Security](#security)).
3. The ID token's role claim decides the role:
   - a value in the provider's **admin values** makes the person an admin;
   - otherwise a value in the **read-only values** makes them read-only;
   - otherwise they get no access, unless **Let everyone else in read-only** is on.

   Values compare without regard to case.
4. The first sign-in creates a YadVault account without a password, named after the provider's
   username (the email-like sign-in name). The account's role follows the provider at every
   sign-in. A provider account is never joined to an existing YadVault account, even when the
   names match: it gets a name like `owner (Microsoft)` instead.
5. A single sign-on session ends a fixed time after the sign-in (24 hours by default, Settings →
   Single sign-on → Options), so the provider decides again. When the provider turns someone
   away, their open YadVault sessions end too.

Accounts made by single sign-on count towards the number of accounts your license allows.

## Before you start

- **Pro.** Single sign-on needs a YadVault Pro license ([licensing.md](licensing.md)).
- **HTTPS.** Entra ID only accepts `https://` redirect addresses (except `localhost`), and you
  should not send sign-ins over plain HTTP anyway. Turn on HTTPS first ([https.md](https.md)). A
  name with a Let's Encrypt certificate works best. With the local certificate authority, every
  device must trust it.
- **The address people open.** YadVault builds the redirect address from the address of the
  visit. Behind a proxy, or when people use several names, set Settings → Single sign-on →
  Options → **Public address** (for example `https://archive.example.com`). The redirect
  address is then `<public address>/api/auth/sso/<provider>/callback`.
- **Outbound HTTPS.** The app container must reach the provider: `login.microsoftonline.com` for
  Entra ID, your Okta domain for Okta. Through a proxy, set `HTTPS_PROXY` in `.env`. People's
  browsers reach the provider directly.
- **The clock.** YadVault checks the times in ID tokens and allows two minutes of difference.
  Keep the server's clock right (NTP).

In YadVault, open Settings → Single sign-on, click **Add Entra ID** or **Add Okta**, and copy the
**Redirect address** shown at the top of the form. You need it at the provider.

## Microsoft Entra ID

In the [Microsoft Entra admin center](https://entra.microsoft.com):

1. **Register the application.** Open **App registrations** (search for it at the top of the
   admin center) → New registration.
   - Name: `YadVault`.
   - Supported account types: *Accounts in this organizational directory only*.
   - Redirect URI: platform **Web**, the redirect address from YadVault.

   Then click Register.
2. **Copy the IDs.** On the application's **Overview**, copy the *Application (client) ID* and the
   *Directory (tenant) ID*.
3. **Create a client secret.** Go to Certificates & secrets → Client secrets → New client secret,
   and choose an expiry. Copy the **Value** at once: it is shown only once, and it is not the
   *Secret ID*. Put a reminder in your calendar to renew it before it expires.
4. **Create the roles** (recommended). Under **App roles**, create two roles:

   | Display name | Allowed member types | Value |
   |---|---|---|
   | YadVault admins | Users/Groups | `YadVault.Admin` |
   | YadVault readers | Users/Groups | `YadVault.Reader` |

5. **Assign people.** Open **Enterprise applications** → YadVault → Users and groups → Add
   user/group. Pick people or groups and a role. Assigning groups needs
   Entra ID P1 or P2; on the free tier, assign people one by one.
6. **Require assignment** (recommended). Under Enterprise applications → YadVault → Properties,
   set *Assignment required?* to **Yes**. People who are not assigned are then stopped by Entra
   ID itself, and YadVault explains it on its sign-in page.
7. **Fill in YadVault.** Add Entra ID with:
   - the directory (tenant) ID;
   - the application (client) ID;
   - the client secret's value;
   - role claim **App roles**;
   - admin values `YadVault.Admin` and read-only values `YadVault.Reader`.

   Save, then use **Check** and **Test sign-in** (see [Testing](#testing)).

**Groups instead of app roles.** Under the app registration's **Token configuration**, choose *Add
groups claim* → *Security groups* → ID token: *Group ID*. In YadVault, choose role claim
**Groups** and enter the groups' *Object IDs* (Entra ID → Groups → the group → Overview). A token
holds at most 200 groups. Someone in more groups gets none in the token, and YadVault says so. In
that case use app roles, or choose *Groups assigned to the application* in the groups claim.

The directory's domain (`contoso.onmicrosoft.com`) also works as the tenant. YadVault checks that
tokens come from that directory and no other. Multi-tenant sign-in (`common`, `organizations`)
is not supported.

## Okta

In the Okta Admin Console:

1. **Create the application.** Go to Applications → Applications → Create App Integration, and
   choose **OIDC - OpenID Connect**, application type **Web Application**.
   - App integration name: `YadVault`.
   - Grant type: Authorization Code.
   - Sign-in redirect URIs: the redirect address from YadVault. Remove the default sign-out
     redirect.
   - Assignments: limit access to the groups that may use YadVault.
2. **Copy the client credentials.** On the **General** tab, copy the *Client ID* and a *Client
   secret* (client authentication: client secret). You may tick *Require PKCE*: YadVault always
   sends it.
3. **Create groups.** Under Directory → Groups, create `YadVault Admins` and `YadVault Readers`.
   Add people, and assign both groups to the application (Applications → YadVault → Assignments).
4. **Put the groups into the ID token.** How depends on the issuer you use:
   - **Org authorization server** (issuer `https://your-org.okta.com`). Go to Applications →
     YadVault → Sign On → OpenID Connect ID Token → Edit. Set *Groups claim type* to Filter and
     the *Groups claim filter* to `groups` *Matches regex* `.*`. A narrower filter also works,
     for example *Starts with* `YadVault`. Keep the scope `groups` in YadVault (the default).
   - **Custom authorization server** (issuer `https://your-org.okta.com/oauth2/default`). Go to
     Security → API → Authorization Servers → default → Claims → Add Claim:
     - name `groups`;
     - include in **ID Token**, *Always*;
     - value type *Groups*, filter *Matches regex* `.*`;
     - include in *Any scope*.

     In YadVault, open Advanced → Scopes and remove `groups`, leaving `openid profile email`.
     The server's access policy must allow the application; the default rule does.
5. **Fill in YadVault.** Add Okta with:
   - the issuer;
   - the client ID and secret;
   - role claim `groups`;
   - admin values `YadVault Admins` and read-only values `YadVault Readers`.

   Save, then use **Check** and **Test sign-in**.

## Testing

- **Check** fetches the provider's metadata and signing keys. It shows the issuer and the
  redirect address YadVault sends, and it signs nobody in.
- **Test sign-in** (admins only) runs a real sign-in in your browser. Sign in at the provider as
  any person, for example a colleague in a private window. YadVault then shows:
  - what the provider sent: account, identifier, and the values of the role claim;
  - the role those values give, and why.

  It opens no session and creates no account. Use it to check the mapping before you turn the
  provider on for everyone. A provider that is switched off can still be tested.

When a sign-in fails, the sign-in page explains it in one sentence. Admins find the details in the
app's log (`docker compose logs app`, logger `yadvault.sso`) and in the audit log (`sso_login`,
`sso_denied`). Tokens and codes are never written anywhere.

| On the sign-in page | Meaning |
|---|---|
| not in a group or role that may use YadVault | Signed in at the provider, but no role value matched (and *everyone else* is off) |
| not assigned to YadVault | The provider refused: the person is not assigned to the application |
| cancelled or refused at the provider | The person cancelled, or consent is missing |
| answer could not be verified | The ID token failed a check: client ID, tenant or issuer, or the server's clock |
| could not be reached | YadVault cannot reach the provider: DNS, outbound HTTPS, proxy |
| not set up correctly | The provider's metadata names another issuer, or a required address is missing |
| took too long or was started in another browser | More than ten minutes passed, or the browser lost YadVault's sign-in cookie |
| allows no more accounts | The license's account limit is reached |

## Troubleshooting

| Provider's message | Fix |
|---|---|
| AADSTS50011 (redirect URI mismatch) | Register the exact redirect address from YadVault, including scheme, name and port. Behind a proxy, set the public address |
| AADSTS700016 (application not found) | Wrong client ID, or the tenant is another directory |
| AADSTS7000215 (invalid client secret) | You copied the Secret ID instead of the Value, or the secret has expired |
| AADSTS50105 (not assigned) | Assign the person or a group of theirs under Enterprise applications |
| AADSTS65001 (consent) | An admin grants consent under App registrations → API permissions |
| Okta: *redirect_uri must be a Login redirect URI* | Add the exact redirect address to the app's sign-in redirect URIs |
| Okta: *User is not assigned to the client application* | Assign the person or a group of theirs to the application |
| Okta: *One or more scopes are not configured* | With a custom authorization server, remove `groups` from the scopes |
| Token "not valid yet" or "expired" | The server's clock is off: turn on time synchronization |

## Password sign-in

Settings → Single sign-on → Options → **Password sign-in** has two choices:

- **Everyone with a password** (the default): local accounts keep signing in with their
  passwords.
- **Only the first admin**: while a provider is switched on, only the first admin may use a
  password. Everyone else must use single sign-on.

Keep the first admin's password in a safe place. If the provider is down, or a setting locks
everyone out, that account still signs in and can fix the configuration. If its password is lost,
set a new one on the server (this also ends the account's sessions):

```bash
docker compose exec app yadvault users set-password <username>
```

## Security

- **The sign-in exchange.** The authorization code flow with PKCE (S256) is used. State, nonce
  and the PKCE verifier stay on the server. They are bound to a short-lived, HttpOnly cookie in
  the browser that started the sign-in, so an answer cannot be replayed or delivered to another
  browser.
- **ID token checks.** The token's signature is checked with the provider's published keys
  (refetched when the provider rotates them). Tokens signed with a shared secret (HS256) or
  unsigned (`none`) are refused. Issuer, audience (and authorized party), expiry, issue time and
  nonce are checked, allowing 2 minutes of clock difference.
- **Where people land after signing in.** Only an address on this site; YadVault never redirects
  elsewhere.
- **What is stored.** The client secret is kept in a table only YadVault itself reads, never in
  `.env`. Admins never see it again after saving. Tokens are not stored. Of each identity,
  YadVault keeps the provider's identifier (Entra ID object ID or Okta user ID), the email
  address and the name.
- **Rate limit.** Sign-in starts and returns are limited per address.
