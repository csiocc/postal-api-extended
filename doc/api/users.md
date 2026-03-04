# Postal API: Users (Legacy v1)

This page documents the user endpoints under `/api/v1/users`.

## Endpoints

- `GET /api/v1/users`
- `POST /api/v1/users`
- `GET /api/v1/users/:uuid`
- `PATCH /api/v1/users/:uuid`
- `PUT /api/v1/users/:uuid`
- `DELETE /api/v1/users/:uuid`

## Authentication & Authorization

Every request needs a server API key:

```http
X-Server-API-Key: <api_key>
```

User management is **admin-only**.  
The API actor is derived from the owner of the credential's server organization.

- If that owner has `admin=true`: full user management scope across organizations.
- If not: request is rejected with `AccessDenied`.

## Response Format

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
| `AccessDenied` | Missing auth or non-admin actor |
| `InvalidServerAPIKey` | API key does not exist |
| `ServerSuspended` | Credential belongs to a suspended server |
| `UserNotFound` | UUID not found in visible scope |
| `CannotModifySelf` | Attempt to remove own admin role or delete own account |

`parameter-error` is used for malformed/invalid input.

## Notes per Endpoint

### `GET /api/v1/users`

Lists visible users, ordered by `first_name`, `last_name`.

### `GET /api/v1/users/:uuid`

Returns one user with details (`organizations`, `email_verified_at`, `oidc`).

### `POST /api/v1/users`

Creates a user.

Request fields:

| Field | Type | Required | Notes |
|---|---|---|---|
| `email_address` | string | yes | valid + unique |
| `first_name` | string | yes | |
| `last_name` | string | yes | |
| `password` | string | yes | |
| `password_confirmation` | string | yes | must match |
| `admin` | boolean | no | defaults to `false` |
| `time_zone` | string | no | defaults to `UTC` |
| `organization_ids` | array[int] | no | must be array of integers |

### `PATCH/PUT /api/v1/users/:uuid`

Partial update. Password update requires both `password` and `password_confirmation`.

Self-protection:
- an admin cannot remove their own admin role (`CannotModifySelf`).

### `DELETE /api/v1/users/:uuid`

Deletes a user.

Self-protection:
- an admin cannot delete their own account (`CannotModifySelf`).
