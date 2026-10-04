# Building Cartograph in GitHub Actions

The `Build Cartograph` workflow uses **GitHub-hosted `windows-2022` machines**. No self-hosted runner or personal Windows VM is required. It runs on pushes, published releases, and manual dispatches, builds the editor target, and packages the Windows client mod for Satisfactory (including Proton).

## Required Actions secrets

Under **Settings → Secrets and variables → Actions → Secrets**, add:

- `CSS_ENGINE_TOKEN`: a GitHub token from an account authorized to read `satisfactorymodding/UnrealEngine`. The workflow downloads the custom CSS Unreal Editor. This repository's default `GITHUB_TOKEN` cannot access that separate private repository.
- `WWISE_EMAIL` and `WWISE_PASSWORD`: credentials for an authorized Audiokinetic account. The workflow downloads Wwise SDK `2023.1.14.8770` and integrates Unreal plugin version `2023.1.14.3555` using `wwise-cli`.

These licensed dependencies cannot be downloaded without the relevant access. Do not commit credentials, engine files, or Wwise files to the repository.

Optionally set the **Actions variable** `CSS_ENGINE_RELEASE` to the engine release tag for `5.6.1-CSS`. Otherwise the latest release is used. The workflow rejects engine versions other than 5.6.1.

## Downloading the build

Open **Actions → Build Cartograph**, select a successful run, and download `Cartograph-Windows-<run>` under **Artifacts**. Artifacts are retained for 90 days. Published-release builds upload Actions artifacts, not release attachments.

## Hosted-runner limits

The engine is large. Downloading, extracting, and compiling must fit the hosted runner's disk and memory limits and the six-hour job timeout. This configuration has not yet completed a build; if resources are exhausted, the run will fail rather than silently substitute a different mod or engine. Repository credentials alone do not increase runner resources.
