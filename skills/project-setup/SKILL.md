---
name: project-setup
description: "Command-only skill for `$project-setup`. Use only when the user explicitly invokes `$project-setup` or `project-setup` to list globally installed Codex skills/plugins, let the user return an edited selection, and copy only those selected resources into the current project."
---

# Project Setup

## Overview

Copy selected global Codex skills and local plugins into a project without guessing what the project should receive. The first pass is inventory-only; installation happens only after the user returns an explicit filtered selection.

## Trigger Contract

Use this skill only for explicit command forms:

- `$project-setup`
- `project-setup`
- `$project-setup <edited JSON selection>`
- `project-setup <edited JSON selection>`

Do not trigger implicitly for generic project initialization requests.

## Inventory Mode

When the user invokes `$project-setup` without a selection:

1. Run:

```powershell
python C:\Users\imale\.codex\skills\project-setup\scripts\project_setup.py inventory
```

2. Return the generated JSON to the user in a fenced `json` block.
3. Tell the user to delete every skill/plugin they do not want and send back only the resources that should be installed in the project.
4. Do not copy files, update project config, or register marketplaces in inventory mode.

## Install Mode

When the user returns an edited selection:

1. Confirm the current working directory is the target project root.
2. Save the returned JSON into a temporary file under `.codex/project-setup-selection.json`.
3. Run:

```powershell
python C:\Users\imale\.codex\skills\project-setup\scripts\project_setup.py install --selection .codex\project-setup-selection.json --project-root .
```

4. Report installed paths and the generated or updated project marketplace path.
5. If plugins were installed, report the exact registration command:

```powershell
codex plugin marketplace add <project-root>
```

Do not run the registration command automatically unless the user explicitly asks.

## Copy Targets

Install selected skills into:

```text
.agents/skills/<skill-name>/
```

Install selected plugins into:

```text
plugins/<plugin-name>/
.agents/plugins/marketplace.json
```

The project marketplace entry uses `INSTALLED_BY_DEFAULT` so the plugin is discoverable when the project marketplace is registered.

## Cross-Platform Scripts

- Project setup resources are meant to work on Windows and Linux.
- When installing selected resources, any project automation copied as a `.ps1` script should have an equivalent `.sh` script with the same basename and purpose.
- If a selected resource contains `.ps1` files without matching `.sh` files, report those paths as post-install warnings so the project can receive Linux equivalents before relying on the setup.
- Keep PowerShell and shell variants behaviorally aligned for setup, install, bootstrap, validation, and service-management commands.

## Selection Rules

- Copy only resources explicitly returned by the user.
- Do not copy `.system` skills unless the user intentionally keeps them in the edited selection.
- Do not copy non-local plugins whose source path is empty or marked non-copyable.
- Do not edit global `~/.codex/config.toml`.
- Preserve unrelated project files.
- If a destination already exists, merge/update it with the selected global resource instead of deleting the whole project directory.
