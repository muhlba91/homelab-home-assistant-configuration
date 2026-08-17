# Homelab: Home Assistant - Configuration

[![](https://img.shields.io/github/license/muhlba91/homelab-home-assistant-configuration?style=for-the-badge)](LICENSE.md)
[![](https://img.shields.io/github/actions/workflow/status/muhlba91/homelab-home-assistant-configuration/verify.yml?style=for-the-badge)](https://github.com/muhlba91/homelab-home-assistant-configuration/actions/workflows/verify.yml)
[![](https://api.scorecard.dev/projects/github.com/muhlba91/homelab-home-assistant-configuration/badge?style=for-the-badge)](https://scorecard.dev/viewer/?uri=github.com/muhlba91/homelab-home-assistant-configuration)

This repository contains [Home Assistant](http://home-assistant.io) configuration, and lifecycle scripts.

---

## Configuration

The repository is split into two layers:

- **Common** ([`common/configuration/`](common/configuration/)): shared configuration, automations, blueprints, and component lists applied to every site.
- **Sites** ([`sites/`](sites/)): site-specific configuration, automations, and encrypted secrets. Each subdirectory (e.g. [`sites/vie/`](sites/vie/)) represents one Home Assistant instance.

The main configuration entry point is [`common/configuration/configuration.yaml`](common/configuration/configuration.yaml).
Site secrets are stored per-site in `sites/<site>/configuration/secrets.enc.yaml` (e.g. [`sites/vie/configuration/secrets.enc.yaml`](sites/vie/configuration/secrets.enc.yaml)).

### Secrets Encryption

All secrets are encrypted with [sops](https://github.com/mozilla/sops) and [Google Cloud KMS](https://cloud.google.com/security-key-management).

## Components

Custom integration and frontend (www) component versions are pinned in:

- [`common/components/custom_components.txt`](common/components/custom_components.txt): HACS-style custom integrations, cloned from GitHub at the specified tag.
- [`common/components/www_components.txt`](common/components/www_components.txt): Lovelace frontend resources, downloaded from GitHub releases.
- [`common/configuration/frontend/extra_module_url.yaml`](common/configuration/frontend/extra_module_url.yaml): additional frontend module URLs loaded by Home Assistant.

All versions are kept up-to-date automatically via [Renovate](https://docs.renovatebot.com/) using the custom regex managers defined in [`renovate.json`](renovate.json).

## Lifecycle Scripts

The directory [`lifecycle`](lifecycle/) contains all lifecycle scripts:

- [`prepare.sh`](lifecycle/prepare.sh): installs all custom and www components defined in [`common/components/custom_components.txt`](common/components/custom_components.txt) and [`common/components/www_components.txt`](common/components/www_components.txt).
  Downloads for each component type are staged into a temporary directory first; the live destination is only replaced once **all** downloads for that type succeed.
  If any download within a component type fails, a warning is printed, that entire type is skipped, and the script continues with exit code 0.
- [`sops.sh`](lifecycle/sops.sh): encrypts or decrypts all necessary secret files (pass `e` for encryption, `d` for decryption).
- [`backup_restore.sh`](lifecycle/backup_restore.sh): checks if data exists and either backs up or restores the Home Assistant `.storage/` directory to/from [Scaleway Object Storage](https://www.scaleway.com/en/object-storage/) (S3-compatible). Optionally copies the repository configuration into the data directory when `COPY_CONFIG=true`.
