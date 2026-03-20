# Postal API: Management Credentials

This page documents the credential endpoints under `/api/v1/manage/credentials`.

## Endpoints

- `GET /api/v1/manage/credentials`
- `POST /api/v1/manage/credentials`
- `GET /api/v1/manage/credentials/:uuid`
- `PATCH /api/v1/manage/credentials/:uuid`
- `PUT /api/v1/manage/credentials/:uuid`
- `DELETE /api/v1/manage/credentials/:uuid`

## Authentication and Authorization

Every request needs a management API key in the header:

```http
X-Management-API-Key: <management_api_key>
```

Management keys are bound to admin users and have global management scope.
Requests with only `X-Server-API-Key` are rejected.

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
| `AccessDenied` | Missing auth or wrong header type |
| `InvalidManagementAPIKey` | API key does not exist |
| `ManagementAPIKeyRevoked` | API key has been revoked |
| `CredentialNotFound` | UUID is missing or outside current visibility scope |
| `ServerNotFound` | Provided `server_id` does not exist |

`parameter-error` is used for malformed/invalid request input.

---

## `GET /api/v1/manage/credentials`

Returns credentials visible in the current scope (`Credential` entries attached to visible servers), ordered by `name`.

Optional query params:
- `server_id` (integer): limits results to credentials of that server
  - unknown `server_id` returns `ServerNotFound`
  - non-integer `server_id` returns `parameter-error`
- `page` (default `1`)
- `per_page` (default `50`, max `100`)

Success payload:
- `data.credentials` array
- `data.total` count
- `data.pagination` metadata

---

## `GET /api/v1/manage/credentials/:uuid`

Returns one credential with detailed payload.

Response includes:
- basic credential fields (`uuid`, `name`, `key`, `type`, `hold`, timestamps)
- `server` details with nested `organization`
- `options`

If credential is missing or outside scope:

```json
{
  "status": "error",
  "data": {
    "code": "CredentialNotFound"
  }
}
```

---

## `POST /api/v1/manage/credentials`

Creates a credential.

### Request body

| Field | Type | Required | Notes |
|---|---|---|---|
| `type` | string | no | allowed: `SMTP`, `API`, `SMTP-IP`; defaults to `SMTP` if omitted |
| `name` | string | yes | |
| `key` | string | no | generated automatically for non-`SMTP-IP` credentials |
| `hold` | boolean | no | accepts `true/false`, `1/0`, `"true"/"false"` |
| `server_id` | integer | yes | target server for the new credential |

Validation and scope behavior:
- missing `server_id` returns `parameter-error`
- unknown `server_id` returns `ServerNotFound`
- malformed JSON returns `parameter-error` with `Request body must contain valid JSON.`
- invalid fields/values return `parameter-error`

---

## `PATCH/PUT /api/v1/manage/credentials/:uuid`

Updates an existing credential.

Supported fields:
- `name`
- `key` (only valid for `SMTP-IP` credentials due model validation)
- `hold`

Behavior:
- partial update (only provided fields are changed)
- invalid `hold` value returns `parameter-error`
- out-of-scope/missing credential returns `CredentialNotFound`

---

## `DELETE /api/v1/manage/credentials/:uuid`

Deletes a credential.

Success:
- `status=success`
- message `Credential <name> has been deleted`

Out-of-scope/missing credential:
- `error` with `CredentialNotFound`

---
