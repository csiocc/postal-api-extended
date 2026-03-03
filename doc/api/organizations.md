# Postal API: Organizations (Legacy v1)

This page documents the organization endpoints under `/api/v1/organizations`.

## Endpoints

- `GET /api/v1/organizations`
- `POST /api/v1/organizations`
- `GET /api/v1/organizations/:uuid`
- `PATCH /api/v1/organizations/:uuid`
- `PUT /api/v1/organizations/:uuid`
- `DELETE /api/v1/organizations/:uuid`

## Authentication and Authorization

Every request needs a server API key in the header:

```http
X-Server-API-Key: <api_key>
```

Organizations endpoint access is restricted to **global-admin API credentials** only.
A valid API key without `options["global_admin"] == true` is rejected with:

```json
{
  "status": "error",
  "data": {
    "code": "AccessDenied",
    "message": "Organization management requires global admin privileges"
  }
}
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
| `AccessDenied` | Missing/invalid auth or non-global credential |
| `InvalidServerAPIKey` | API key does not exist |
| `ServerSuspended` | Credential belongs to a suspended server |
| `OrganizationNotFound` | UUID is missing or not found (including soft-deleted organizations) |
| `UserNotFound` | Provided `owner_uuid` does not exist |

`parameter-error` is used for malformed/invalid request input.

---

## `GET /api/v1/organizations`

Returns all non-deleted organizations (`Organization.present`), ordered by `name`.

Example:

```bash
curl -X GET http://127.0.0.1:5000/api/v1/organizations \
  -H "X-Server-API-Key: <global_api_key>"
```

Success excerpt:

```json
{
  "status": "success",
  "data": {
    "organizations": [
      {
        "uuid": "...",
        "name": "Test Org",
        "permalink": "test",
        "time_zone": "UTC",
        "status": "Active",
        "created_at": "2026-03-03T10:00:00Z",
        "updated_at": "2026-03-03T10:00:00Z"
      }
    ],
    "total": 1
  }
}
```

---

## `GET /api/v1/organizations/:uuid`

Returns one organization with detailed payload.

Example:

```bash
curl -X GET http://127.0.0.1:5000/api/v1/organizations/<organization_uuid> \
  -H "X-Server-API-Key: <global_api_key>"
```

Response includes:
- basic organization fields
- `owner` (`uuid`, `email_address`, `name`)

If organization is missing:

```json
{
  "status": "error",
  "data": {
    "code": "OrganizationNotFound",
    "message": "The requested organization could not be found",
    "uuid": "<requested_uuid>"
  }
}
```

---

## `POST /api/v1/organizations`

Creates an organization.

### Request body

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | |
| `permalink` | string | yes | lowercase letters, digits, `-` only |
| `time_zone` | string | no | default `UTC` |
| `owner_uuid` | string (UUID) | no | if omitted, owner defaults to current admin user from credential context |

Example:

```bash
curl -X POST http://127.0.0.1:5000/api/v1/organizations \
  -H "X-Server-API-Key: <global_api_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Created Organization",
    "permalink": "created-organization",
    "time_zone": "UTC",
    "owner_uuid": "00000000-0000-0000-0000-000000000001"
  }'
```

Success:
- `status=success`
- `data.organization` present (includes `owner`)
- message `Organization <name> created successfully`

Validation and business errors:
- invalid permalink format/reserved/duplicate -> `parameter-error`
- unknown `owner_uuid` -> `error` (`UserNotFound`)

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

## `PATCH/PUT /api/v1/organizations/:uuid`

Updates an existing organization.

Behavior:
- partial update (only supplied fields are changed)
- supported update fields: `name`, `permalink`, `time_zone`

Example:

```bash
curl -X PATCH http://127.0.0.1:5000/api/v1/organizations/<organization_uuid> \
  -H "X-Server-API-Key: <global_api_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Global Updated Org",
    "time_zone": "Europe/Zurich"
  }'
```

Success:
- `status=success`
- `data.organization` present
- message `Organization <name> updated successfully`

Errors:
- unknown UUID -> `OrganizationNotFound`
- validation failure -> `parameter-error`

---

## `DELETE /api/v1/organizations/:uuid`

Soft-deletes an organization.

Example:

```bash
curl -X DELETE http://127.0.0.1:5000/api/v1/organizations/<organization_uuid> \
  -H "X-Server-API-Key: <global_api_key>"
```

Success:
- `status=success`
- message `Organization <name> has been deleted`

Errors:
- unknown UUID -> `OrganizationNotFound`

---
