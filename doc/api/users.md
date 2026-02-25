# Postal API: Users (Legacy v1)

This page documents the user endpoints under `/api/v1/users`.

## Endpoints

- `GET /api/v1/users`
- `POST /api/v1/users`
- `GET /api/v1/users/:uuid`
- `PATCH /api/v1/users/:uuid`
- `PUT /api/v1/users/:uuid`
- `DELETE /api/v1/users/:uuid`

## Authentication

Every request needs a server API key in the header:

```http
X-Server-API-Key: <api_key>
```

A valid key alone is not enough for user management. The owner of the key's server organization must be `admin=true`.
"An API key belongs to a server, and that server belongs to an organization whose owner must be an admin"
If not, you get:

```json
{
  "status": "error",
  "data": {
    "code": "AccessDenied"
  }
}
```

## Scope Rules and how to set global_admin

Default behavior:
- A key is scoped to its own organization.
- Admins can only create or modify users within that organization.
- Reads/updates/deletes outside that scope return `UserNotFound`.

Global-admin behavior:
- Use a dedicated API credential with:
  - `"global_admin" => true`
- Cross-organization actions are allowed only with this global-admin credential setup.
- It must be a real boolean `true`.
- String values like `"true"` or `"false"` do not enable global-admin scope.
- Global admin can only be set via rails console.

Example: (Rails console):
- create new API key with global_admin for server with shortname(permalink) "cockpit-server"
```ruby
server = Server.find_by!(permalink: "cockpit-server")
credential = Credential.create!(
  server: server,
  type: "API",
  name: "Cockpit User Management"
)
credential.update!(
  options: credential.options.merge("global_admin" => true)
)
puts credential.key
```
- Or, if an API key already exists:

```ruby
server = Server.find_by!(permalink: "cockpit-server")
credential = server.credentials.find_by!(
  type: "API",
  key: "xxx"
)
credential.update!(
  options: credential.options.merge("global_admin" => true)
)
puts credential.key
```

## Response Format

Legacy API responses are evaluated by JSON payload, not by HTTP status alone.

```json
{
  "status": "success|error|parameter-error",
  "time": 0.012,
  "flags": {},
  "data": {}
}
```

## Common Error Codes

| Code | Meaning |
|---|---|
| `AccessDenied` | Missing auth, no admin owner, or out-of-scope organization assignment |
| `InvalidServerAPIKey` | API key does not exist |
| `ServerSuspended` | Credential belongs to a suspended server |
| `UserNotFound` | UUID is missing or not visible in current scope |
| `CannotModifySelf` | Attempt to remove own admin role or delete own account |

`parameter-error` is used for malformed/invalid request input.

---

## `GET /api/v1/users`

Returns users visible in the current scope.

Behavior:
- ordered by `first_name`, `last_name`
- returns `users` and `total`

Example:

```bash
curl -X GET http://127.0.0.1:5000/api/v1/users \
  -H "X-Server-API-Key: <api_key>"
```

Success excerpt:

```json
{
  "status": "success",
  "data": {
    "users": [
      {
        "uuid": "...",
        "email_address": "admin@example.com",
        "first_name": "Admin",
        "last_name": "User",
        "name": "Admin User",
        "admin": true,
        "time_zone": "UTC",
        "created_at": "2026-02-25T10:00:00Z",
        "updated_at": "2026-02-25T10:00:00Z"
      }
    ],
    "total": 1
  }
}
```

---

## `GET /api/v1/users/:uuid`

Returns one user with detailed payload.

Example:

```bash
curl -X GET http://127.0.0.1:5000/api/v1/users/<user_uuid> \
  -H "X-Server-API-Key: <api_key>"
```

Response includes:
- basic user fields
- `organizations`
- `email_verified_at`
- `oidc`

If user is missing or outside scope:

```json
{
  "status": "error",
  "data": {
    "code": "UserNotFound",
    "message": "The specified user could not be found",
    "uuid": "<requested_uuid>"
  }
}
```

---

## `POST /api/v1/users`

Creates a user.

### Request body

| Field | Type | Required | Notes |
|---|---|---|---|
| `email_address` | string | yes | must be valid and unique |
| `first_name` | string | yes | |
| `last_name` | string | yes | |
| `password` | string | yes | |
| `password_confirmation` | string | yes | must match password |
| `admin` | boolean | no | default `false` |
| `time_zone` | string | no | default `UTC` |
| `organization_ids` | array[int] | no | validated against scope if present |

- If you want to update/delete that user later with the same key, include `organization_ids` in scope.

Example:

```bash
curl -X POST http://127.0.0.1:5000/api/v1/users \
  -H "X-Server-API-Key: <api_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "email_address": "newuser@example.com",
    "first_name": "Alice",
    "last_name": "Johnson",
    "password": "SecurePassword123!",
    "password_confirmation": "SecurePassword123!",
    "organization_ids": [4]
  }'
```

Success:
- `status=success`
- `data.user` present
- message `User <name> created successfully`

Validation and scope errors:
- invalid email/password mismatch -> `parameter-error`
- `organization_ids` not an array -> `parameter-error` (`organization_ids must be an array of organization IDs`)
- `organization_ids` contains non-integer values -> `parameter-error` (`organization_ids must contain only integer IDs`)
- `organization_ids` outside scope -> `error` (`AccessDenied`)

Malformed JSON body:

```json
{
  "status": "parameter-error",
  "data": {
    "message": "Request body must contain valid JSON."
  }
}
```

---

## `PATCH/PUT /api/v1/users/:uuid`

Updates an existing user.

Behavior:
- partial update (only supplied fields are changed)
- password update needs `password` + `password_confirmation`
- if `organization_ids` key is present, scope validation runs

Example:

```bash
curl -X PATCH http://127.0.0.1:5000/api/v1/users/<user_uuid> \
  -H "X-Server-API-Key: <api_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Alicia",
    "time_zone": "Europe/Berlin"
  }'
```

Self-protection rule:
- admin user cannot remove own admin status
- response: `error` with `CannotModifySelf`

Out-of-scope target:
- `error` with `UserNotFound`

---

## `DELETE /api/v1/users/:uuid`

Deletes a user.

Example:

```bash
curl -X DELETE http://127.0.0.1:5000/api/v1/users/<user_uuid> \
  -H "X-Server-API-Key: <api_key>"
```

Success:
- `status=success`
- message `User <name> has been deleted`

Self-protection rule:
- cannot delete own user account (`CannotModifySelf`)

Out-of-scope or unknown UUID:
- `UserNotFound`

---
