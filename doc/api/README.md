# Postal API Documentation inf pms 01

Complete API reference for Postal mail server.

## Available APIs

### User Management
- [User Management API](./users.md) - Create, read, update, and delete users
- [Server Management API](./servers.md) - Create, read, update, and delete servers

### Legacy API (v1)
- Send Messages
- Query Messages
- View Deliveries

## Authentication

Postal APIs use header-based authentication with API keys:

```
X-Server-API-Key: your_api_key_here
```

### Getting an API Key

1. Log into Postal web interface
2. Navigate to your server settings
3. Go to "Credentials" section
4. Create a new API credential
5. Copy the generated key

## API Response Format

All API responses follow this structure:

```json
{
  "status": "success|error|parameter-error",
  "time": 0.042,
  "flags": {},
  "data": {
    // Response data or error details
  }
}
```

### Status Codes

- `success` - Request completed successfully
- `error` - Request failed due to business logic error
- `parameter-error` - Invalid parameters provided

**Note**: HTTP status code is always `200 OK`. Check the `status` field for actual result.

## Endpoints

| Category        | Endpoint                    | Description                |
|-----------------|----------------------------|----------------------------|
| Users           | `GET /api/v1/users`        | List all users             |
| Users           | `POST /api/v1/users`       | Create new user            |
| Users           | `GET /api/v1/users/:uuid`  | Get user details           |
| Users           | `PATCH /api/v1/users/:uuid`| Update user                |
| Users           | `DELETE /api/v1/users/:uuid`| Delete user               |
| Servers         | `GET /api/v1/servers`      | List visible servers       |
| Servers         | `POST /api/v1/servers`     | Create new server          |
| Servers         | `GET /api/v1/servers/:uuid`| Get server details         |
| Servers         | `PATCH /api/v1/servers/:uuid`| Update server            |
| Servers         | `DELETE /api/v1/servers/:uuid`| Delete server           |
| Messages        | `POST /api/v1/send/message`| Send email message         |
| Messages        | `POST /api/v1/send/raw`    | Send raw email             |


## Support

- [GitHub Discussions](https://github.com/postalserver/postal/discussions)
- [Discord Community](https://discord.postalserver.io)
- [Documentation](https://docs.postalserver.io)
