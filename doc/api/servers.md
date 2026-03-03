# Postal API: Servers (Legacy v1)

This page documents the server endpoints under `/api/v1/servers`.

## Endpoints

- `GET /api/v1/servers`
- `POST /api/v1/servers`
- `GET /api/v1/servers/:uuid`
- `PATCH /api/v1/servers/:uuid`
- `PUT /api/v1/servers/:uuid`
- `DELETE /api/v1/servers/:uuid`

## Authentication and Authorization

Every request needs a server API key in the header:

```http
X-Server-API-Key: <api_key>
```

Server management requires that the owner of the credential's organization has `admin=true`.

Scope rules:
- regular credentials can manage servers only in their own organization
- credentials with `options["global_admin"] == true` can manage servers across organizations

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
| `AccessDenied` | Missing auth, non-admin owner, or out-of-scope target organization |
| `InvalidServerAPIKey` | API key does not exist |
| `ServerSuspended` | Credential belongs to a suspended server |
| `ServerNotFound` | UUID is missing or outside current visibility scope |
| `OrganizationNotFound` | Provided `organization_id` does not exist |

`parameter-error` is used for malformed/invalid request input.

---

## `GET /api/v1/servers`

Returns servers visible in the current scope (`Server.present`, ordered by `name`).

---

## `GET /api/v1/servers/:uuid`

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

## `POST /api/v1/servers`

Creates a server.

### Request body

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | unique within organization |
| `permalink` | string | no | defaults from name if omitted |
| `mode` | string | yes | `Live` or `Development` |
| `organization_id` | integer | no | defaults to credential organization; cross-org only for global admin |

Validation or malformed input returns `parameter-error`.

---

## `PATCH/PUT /api/v1/servers/:uuid`

Updates an existing server.

Supported fields:
- `name`
- `permalink`
- `mode`

Unknown UUID/out-of-scope => `ServerNotFound`.

---

## `DELETE /api/v1/servers/:uuid`

Soft-deletes a server.

Unknown UUID/out-of-scope => `ServerNotFound`.

