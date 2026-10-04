# Building Cartograph in GitHub Actions

This organization copy uses **Blacksmith's `blacksmith-32vcpu-windows-2025` runner**, with **32 vCPU, 112 GB RAM, and 130 GB disk**. Windows runners are currently a Blacksmith public beta. No self-hosted runner or personal Windows VM is required. It runs on pushes, published releases, and manual dispatches, builds the editor target, and packages the Windows client mod for Satisfactory (including Proton).

The personal copy at `wadhah101/Cartograph` is preserved and continues to use the standard `windows-2022` runner.

## Blacksmith setup

Connect the organization at <https://app.blacksmith.sh> and grant the Blacksmith GitHub App access to `wa101200/Cartograph`. The organization already had the app installed for all repositories when this workflow was switched. Blacksmith billing and Windows-runner access are managed through Blacksmith, separately from GitHub Team billing.

The workflow no longer depends on `WINDOWS_16_CORE_READY` or a custom GitHub-hosted runner. Existing GitHub runner resources and `scripts/setup-hosted-runner.py` are retained as a fallback; they are not used by this workflow. Do not run the provisioning script to enable Blacksmith.

Blacksmith includes Visual Studio Build Tools 2022 instead of the full IDE. The required engine/compiler compatibility must still be verified by the build. See <https://docs.blacksmith.sh/blacksmith-runners/overview> for current runner specifications.

## Required Actions secrets

Under **Settings → Secrets and variables → Actions → Secrets**, add:

- `CSS_ENGINE_TOKEN`: a GitHub token from an account authorized to read `satisfactorymodding/UnrealEngine`. The workflow downloads the custom CSS Unreal Editor. This repository's default `GITHUB_TOKEN` cannot access that separate private repository.
- `WWISE_EMAIL` and `WWISE_PASSWORD`: credentials for an authorized Audiokinetic account. The workflow downloads Wwise SDK `2023.1.14.8770` and integrates Unreal plugin version `2023.1.14.3555` using `wwise-cli`.

These licensed dependencies cannot be downloaded without the relevant access. Do not commit credentials, engine files, or Wwise files to the repository.

Optionally set the **Actions variable** `CSS_ENGINE_RELEASE` to the engine release tag for `5.6.1-CSS`. Otherwise the latest release is used. The workflow rejects engine versions other than 5.6.1.

## Downloading the build

Open **Actions → Build Cartograph**, select a successful run, and download `Cartograph-Windows-<run>` under **Artifacts**. Artifacts are retained for 90 days. Published-release builds upload Actions artifacts, not release attachments.

## Build limits

Blacksmith's Windows runners have only 130 GB disk, even at 32 vCPU. Engine extraction and compilation must fit that disk and the six-hour job timeout. Downloaded engine archive parts are deleted after extraction to reclaim space. This configuration has not yet completed a build. CPU count alone does not fix disk, toolchain, or source-code errors.
