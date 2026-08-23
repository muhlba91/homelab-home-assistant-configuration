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

The directory [`lifecycle/`](lifecycle/) contains all executable lifecycle scripts.
All scripts are idempotent and designed to run repeatedly (e.g. via a sidecar or cron).

### Exit code convention

Scripts that perform change detection share a common exit code contract:

| Code | Meaning |
| --- | --- |
| `0` | Nothing changed — all workflows skipped |
| `1` | At least one workflow applied changes |
| `2` | At least one workflow encountered an error |

---

### [`prepare.sh`](lifecycle/prepare.sh)

Installs custom integrations and Lovelace (www) components. Each component type is change-detected by SHA-256 hashing its manifest file — the installation only runs when the manifest has changed since the last successful run.
Downloads are staged in a temporary directory; the live destination is replaced only once **all** downloads for that type succeed.

```sh
./lifecycle/prepare.sh <DATA_PATH> [SOURCE_PATH] [STATE_PATH]
```

| Argument | Default | Description |
| --- | --- | --- |
| `DATA_PATH` | — | Home Assistant data directory |
| `SOURCE_PATH` | `.` | Root of this repository |
| `STATE_PATH` | `mktemp -d` | Directory to persist SHA-256 state between runs |
| `IGNORE_RETURN_VALUES` | `false` | Set to `true` to always exit `0`; echo output still reflects actual state |

No environment variables required.

---

### [`configuration.sh`](lifecycle/configuration.sh)

Copies common and site-specific configuration from the repository into the HA data directory.
Change detection compares SHA-256 digests of both source trees; the copy only runs when content has changed.

```sh
./lifecycle/configuration.sh <DATA_PATH> [SOURCE_PATH] [SITE] [STATE_PATH] [IGNORE_RETURN_VALUES]
```

| Argument | Default | Description |
| --- | --- | --- |
| `DATA_PATH` | — | Home Assistant data directory |
| `SOURCE_PATH` | `.` | Root of this repository |
| `SITE` | `vie` | Site subdirectory under `sites/` |
| `STATE_PATH` | `mktemp -d` | Directory to persist SHA-256 state between runs |
| `IGNORE_RETURN_VALUES` | `false` | Set to `true` to always exit `0`; echo output still reflects actual state |

No environment variables required.

---

### [`sops.sh`](lifecycle/sops.sh)

Encrypts or decrypts all site secret files using [sops](https://github.com/mozilla/sops) and Google Cloud KMS.

```sh
./lifecycle/sops.sh <COMMAND> [SOURCE_PATH]
```

| Argument | Default | Description |
| --- | --- | --- |
| `COMMAND` | — | `d` to decrypt, `e` to encrypt |
| `SOURCE_PATH` | `.` | Root of this repository |

Requires GCP credentials accessible to `sops` (e.g. `GOOGLE_APPLICATION_CREDENTIALS` or Workload Identity).

---

### [`backup_restore.sh`](lifecycle/backup_restore.sh)

Checks whether an existing HA installation is present in `DATA_PATH` (via `secrets.yaml`).
If data exists, uploads `.storage/` to Scaleway Object Storage (backup).
If no data exists, wipes `DATA_PATH` and restores `.storage/` from Scaleway (restore).

```sh
./lifecycle/backup_restore.sh <DATA_PATH>
```

| Argument | Default | Description |
| --- | --- | --- |
| `DATA_PATH` | — | Home Assistant data directory |

| Environment variable | Description |
| --- | --- |
| `SCW_ACCESS_KEY` | Scaleway access key |
| `SCW_SECRET_KEY` | Scaleway secret key |
| `SCW_DEFAULT_REGION` | Scaleway region (e.g. `fr-par`) |
| `S3_ASSETS_BUCKET` | S3 bucket name |
| `S3_ASSETS_BUCKET_PATH` | Key prefix within the bucket |
