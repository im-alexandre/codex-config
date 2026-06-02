---
name: coolify-deploy
description: Automate and validate Coolify deployments through the Coolify API using Python requests for GitHub-backed Docker Compose apps. Use when the user asks to publish, deploy, create a Coolify project/environment/application, configure runtime env vars, patch Docker Compose domains, trigger a deployment, inspect deployment status/logs, or validate a public domain after deploy, especially with deploy_coolify.md, docker-compose.yml, Dockerfile, .env.example, COOLIFY_ACCESS_TOKEN, and COOLIFY_BASE_URL.
---

# Coolify Deploy

## Workflow

1. Read the repo deploy notes first, usually `deploy_coolify.md`, then inspect `docker-compose.yml`, Dockerfile, entrypoint, `.env.example`, and `git status`.
2. Verify locally before touching Coolify: `docker compose --env-file .env.example config`, tests/builds relevant to the stack, and a container smoke test when feasible.
3. Commit and push deploy changes before asking Coolify to build. Coolify deploys from the remote branch, not local uncommitted files.
4. When the target project, environment, domain, application, and auto-deploy branch already exist and are healthy, do not trigger a manual redeploy for every code change. Push the target branch and monitor the deployment created by the GitHub App/webhook instead. Trigger deploy manually only for initial provisioning, changed Coolify configuration/env vars, disabled or failed auto-deploy, or an explicit user request.
5. Authenticate with `COOLIFY_ACCESS_TOKEN` and `COOLIFY_BASE_URL` from the environment. Do not print token values or generated secrets.
6. Use the Coolify API idempotently: find or create project, environment, application, env vars, patch Docker Compose domains when needed, then deploy by application UUID and poll deployment status.
7. Validate the public domain by direct HTTP/HTTPS requests to `/` and expected API routes. Report exact status codes and Coolify UUIDs.

## Defaults

- Coolify base URL comes from `COOLIFY_BASE_URL`, unless the user provides `--coolify-url`.
- Prefer branch `master` only when it is current and pushed; otherwise use the branch the user explicitly requests.
- For Docker Compose apps, pass `docker_compose_location` with a leading slash, for example `/docker-compose.yml`.
- For Docker Compose app domains, do not rely only on creation payloads or MCP wrappers. After the app exists, patch `PATCH /api/v1/applications/{uuid}` with `docker_compose_domains`, `force_domain_override=true`, and `instant_deploy=true` when the requested public domain must be enforced.
- For Docker Compose app domains, do not add or preserve manual Traefik `custom_labels` for host routing. They can override or confuse Coolify-managed domain interpolation.
- Use `build_pack=dockercompose`, `ports_exposes=80`, `is_auto_deploy_enabled=true`, and `is_force_https_enabled=true` unless the repo says otherwise.
- If Coolify creates an automatic `production` environment but the requested environment is `prod`, create/use `prod`; remove the empty automatic environment only when it has no resources and the runbook requires `prod`.

## Safety

- Never print `COOLIFY_ACCESS_TOKEN`, generated `SECRET_KEY`, database passwords, manual webhook secrets, sentinel tokens, or full application JSON that may contain secrets.
- When listing resources, emit filtered summaries: names, UUIDs, status, branch, repository, and domain only.
- Generate strong runtime secrets when placeholders such as `change_me` are present.
- Do not store Coolify API tokens in repo files. Use environment variables or one-off shell scope.
- If using web for Coolify API docs, restrict to official Coolify documentation unless the user asks otherwise.

## Python Script

Use `scripts/deploy_coolify.py` for the repeatable path. It uses `requests` and:

- reads `COOLIFY_ACCESS_TOKEN` and `COOLIFY_BASE_URL`;
- creates or reuses project/environment/app;
- updates env vars in bulk;
- triggers a force deploy;
- polls deployment status;
- validates root and API URLs.
- patches Docker Compose domains after app creation or reuse.

Example:

```powershell
$env:COOLIFY_ACCESS_TOKEN = "<token>"
$env:COOLIFY_BASE_URL = "https://coolify.example.com"
python C:\Users\imale\.codex\skills\coolify-deploy\scripts\deploy_coolify.py `
  --project-name ordinais `
  --environment-name prod `
  --repository im-alexandre/ordinais `
  --branch master `
  --domain https://electremor.drg.ink `
  --service-name electre_mor `
  --server-uuid uswc0ggc0wwo0g8wc0oscwwo `
  --github-app-uuid c8k8s8wcw8kksg4ws8gc8w0s `
  --compose-location /docker-compose.yml `
  --api-path /api/v1/ `
  --django-default-envs
```

Add custom envs with repeated `--env KEY=VALUE`. Use `--skip-deploy` only for provisioning without publishing.

If the script fails because a Coolify endpoint changed, inspect official API docs and retry with the smallest correction.

## Docker Compose Domain Rule

For Docker Compose resources, the reliable path is:

1. create or reuse the application;
2. `PATCH /api/v1/applications/{uuid}` with:
   - `docker_compose_domains`;
   - `force_domain_override=true`;
   - `instant_deploy=true` when the domain change should apply immediately;
3. if the resource still has manual Traefik `custom_labels` for routing, stop and remove them before trusting the result;
4. only then validate the public host and proxy routing.

If MCP tools do not expose `docker_compose_domains`, prefer the direct HTTP API for that step instead of trying to force `fqdn`, generic `domains` fields, or manual Traefik labels.
