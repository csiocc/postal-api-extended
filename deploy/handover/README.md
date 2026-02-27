# Postal Handover (Server)

This setup pulls the image from GHCR and starts Postal with Docker Compose.

## Prerequisites

- Docker + Docker Compose plugin installed
- Access to image `ghcr.io/<owner>/<repo>`
- `config/signing.key` provided

## Setup

```bash
cd deploy/handover
cp .env.example .env
cp config/postal.production.example.yml config/postal.yml
```

Adjust:

- `.env` (especially `POSTAL_IMAGE`, DB credentials, hostnames)
- `config/postal.yml`

Example:

```env
POSTAL_IMAGE=ghcr.io/your-org-or-user/your-repo:latest
```

## Start

If package is private:

```bash
echo "<github_pat_with_read:packages>" | docker login ghcr.io -u <github-username> --password-stdin
```

Start services:

```bash
cd deploy/handover
./start-from-ghcr.sh
```

## Operations

Update DB schema after new image:

```bash
docker compose --env-file .env -f docker-compose.handover.yml run --rm postal-web postal update
```

Restart:

```bash
docker compose --env-file .env -f docker-compose.handover.yml up -d
```

Logs:

```bash
docker compose --env-file .env -f docker-compose.handover.yml logs -f postal-web
```
