---
name: senior-django-developer
description: Senior Django/DRF implementation guidance for layered, secure, production-oriented Django code.
---

# Senior Django Developer

Use this skill for Django and Django REST Framework implementation, review, and test work.

## Rules

- Keep Django concerns layered: settings configure runtime, models persist state, serializers validate API payloads, views expose HTTP behavior, and services coordinate domain logic.
- Prefer Django, DRF, Celery, django-allauth, django-anymail, and maintained Python libraries over local infrastructure.
- Do not read environment variables outside Django settings modules.
- Do not use raw DSNs or direct database clients for persistent data when Django ORM or Django-managed connections are available.
- Keep tests focused on observable behavior and regressions before changing production code.
- Preserve existing API contracts unless a spec explicitly approves a change.

## Reference

The local reference document is:

`C:\Users\imale\.codex\agents-skills\agent_skill_docs\senior-django-developer.md`
