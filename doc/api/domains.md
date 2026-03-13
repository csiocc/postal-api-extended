# Postal API: Management Domains

This page documents domain endpoints under `/api/v1/manage/domains`.

## Endpoints

- `GET /api/v1/manage/domains`
- `POST /api/v1/manage/domains`
- `GET /api/v1/manage/domains/:uuid`
- `PATCH /api/v1/manage/domains/:uuid`
- `PUT /api/v1/manage/domains/:uuid`
- `DELETE /api/v1/manage/domains/:uuid`
- `POST /api/v1/manage/domains/:uuid/verify`

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
| `AccessDenied` | Missing auth or out-of-scope target |
| `InvalidServerAPIKey` | API key does not exist |
| `ServerSuspended` | Credential belongs to a suspended server |
| `DomainNotFound` | UUID is missing or outside current visibility scope |
| `ServerNotFound` | Provided `server_id` does not exist |
| `OrganizationNotFound` | Provided `organization_id` does not exist |
| `DomainVerificationFailed` | DNS verification execution failed |

`parameter-error` is used for malformed/invalid input.

---

## Domain Object

The API returns domain data including scope, DNS expectations, and verification metadata.

Top-level fields include:
- `id` / `uuid`
- `name`
- `scope` (`server` or `organization`)
- `server_id`
- `organization_id`
- `status` (`pending`, `pending_dns`, `verifying`, `verified`, `failed`)
- `status_reason`
- `verification_method`
- `outgoing`, `incoming`, `use_for_any`
- `last_verification_at`, timestamps

Detailed responses (`show`, `create`, `update`, `verify`) also include:
- `dns` (`spf`, `dkim`, `return_path`, `dmarc` expected records)
- `verification` (`last_result`, `details`)
- owner context (`server`/`organization` hashes)

---

## `GET /api/v1/manage/domains`

Returns all visible domains.

Optional filters:
- `scope`: `server` or `organization`
- `status`: `pending`, `pending_dns`, `verifying`, `verified`, `failed`
- `server_id`: integer
- `organization_id`: integer

Success payload:
- `data.domains` array
- `data.total` count

---

## `GET /api/v1/manage/domains/:uuid`

Returns one domain with full details.

Out-of-scope or unknown UUID:

```json
{
  "status": "error",
  "data": {
    "code": "DomainNotFound"
  }
}
```

---

## `POST /api/v1/manage/domains`

Creates a domain.

### Request body

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | lowercase letters, digits, `-`, `.` |
| `server_id` | integer | no | target server scope |
| `organization_id` | integer | no | target organization scope |
| `scope` | string | no | `server` or `organization` (optional hint) |

Rules:
- `server_id` and `organization_id` are mutually exclusive.
- if neither is provided, target defaults to current credential server.
- verification method is fixed to `DNS` on create.
- out-of-scope targets return `AccessDenied`.

---

## `PATCH/PUT /api/v1/manage/domains/:uuid`

Updates an existing domain.

Supported fields:
- `name`
- `verification_method`
- `outgoing`
- `incoming`
- `use_for_any`
- `rotate_dkim_key` (boolean)

`rotate_dkim_key=true` generates a new DKIM keypair for the domain.

---

## `POST /api/v1/manage/domains/:uuid/verify`

Triggers DNS checks (SPF, DKIM, MX, return-path) and updates verification details.

Optional body:
- `force` (boolean, accepted for compatibility)

Success returns updated domain details including `verification`.

---

## `DELETE /api/v1/manage/domains/:uuid`

Deletes a domain.

Out-of-scope or unknown UUID returns `DomainNotFound`.
