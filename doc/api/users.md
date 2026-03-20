# Postal API: Management Users

This page documents the user endpoints under `/api/v1/manage/users`.

## Endpoints

- `GET /api/v1/manage/users`
- `POST /api/v1/manage/users`
- `GET /api/v1/manage/users/:uuid`
- `PATCH /api/v1/manage/users/:uuid`
- `PUT /api/v1/manage/users/:uuid`
- `DELETE /api/v1/manage/users/:uuid`

## Authentication & Authorization

Every request needs a management API key:

```http
X-Management-API-Key: <management_api_key>
```

Management keys are bound to admin users, so user management stays admin-only.
Requests with only `X-Server-API-Key` are rejected.

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
| `AccessDenied` | Missing auth or wrong header type |
| `InvalidManagementAPIKey` | API key does not exist |
| `ManagementAPIKeyRevoked` | API key has been revoked |
| `UserNotFound` | UUID not found in visible scope |
| `CannotModifySelf` | Attempt to remove own admin role or delete own account |

`parameter-error` is used for malformed/invalid input.

## Notes per Endpoint

### `GET /api/v1/manage/users`

Lists visible users, ordered by `first_name`, `last_name`.

Pagination query params:
- `page` (default `1`)
- `per_page` (default `50`, max `100`)

Success payload includes:
- `data.users`
- `data.total`
- `data.pagination`

### `GET /api/v1/manage/users/:uuid`

Returns one user with details (`organizations`, `email_verified_at`, `oidc`).

### `POST /api/v1/manage/users`

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

### `PATCH/PUT /api/v1/manage/users/:uuid`

Partial update. Password update requires both `password` and `password_confirmation`.

Self-protection:
- an admin cannot remove their own admin role (`CannotModifySelf`).

### `DELETE /api/v1/manage/users/:uuid`

Deletes a user.

Self-protection:
- an admin cannot delete their own account (`CannotModifySelf`).
