# Postal API: Management Servers

This page documents the server endpoints under `/api/v1/manage/servers`.

## Endpoints

- `GET /api/v1/manage/servers`
- `POST /api/v1/manage/servers`
- `GET /api/v1/manage/servers/:uuid`
- `PATCH /api/v1/manage/servers/:uuid`
- `PUT /api/v1/manage/servers/:uuid`
- `DELETE /api/v1/manage/servers/:uuid`

## Authentication and Authorization

Every request needs a server API key in the header:

```http
X-Server-API-Key: <api_key>
```

The API actor is the owner of the credential's server organization.

Scope rules:
- admin actor (`admin=true`): all organizations
- non-admin actor: organizations they own or are assigned to

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
| `AccessDenied` | Missing auth or out-of-scope target organization |
| `InvalidServerAPIKey` | API key does not exist |
| `ServerSuspended` | Credential belongs to a suspended server |
| `ServerNotFound` | UUID is missing or outside current visibility scope |
| `OrganizationNotFound` | Provided `organization_id` does not exist |

`parameter-error` is used for malformed/invalid request input.

---

## `GET /api/v1/manage/servers`

Returns servers visible in the current scope (`Server.present`, ordered by `name`).

---

## `GET /api/v1/manage/servers/:uuid`

Returns one server.

If the server is missing or outside scope:

```json
{
  "status": "error",
  "data": {
    "code": "ServerNotFound"
  }
}
```

---

## `POST /api/v1/manage/servers`

Creates a server.

### Request body

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | unique within organization |
| `permalink` | string | no | defaults from name if omitted |
| `mode` | string | yes | `Live` or `Development` |
| `organization_id` | integer | no | defaults to credential organization |

Validation or malformed input returns `parameter-error`.

---

## `PATCH/PUT /api/v1/manage/servers/:uuid`

Updates an existing server.

Supported fields:
- `name`
- `permalink`
- `mode`

Unknown UUID/out-of-scope => `ServerNotFound`.

---

## `DELETE /api/v1/manage/servers/:uuid`

Soft-deletes a server.

Unknown UUID/out-of-scope => `ServerNotFound`.
