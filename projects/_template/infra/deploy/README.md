# Deployment Assets

This folder stores deployment-only artifacts.

## Required Files

- `docker-compose.yml`
- `.env.example`

## Deployment Command

- `docker compose up --build -d`

## Service Map

| Service | Source Path | Port(s) | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| app | services/<service> | | | |
