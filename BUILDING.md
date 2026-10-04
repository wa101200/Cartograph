# Building Cartograph in GitHub Actions

This organization copy uses the **GitHub-hosted `cartograph-windows-16core` runner**, configured for Windows Server 2022 x64 with **16 cores, 64 GB RAM, and 600 GB SSD**. No self-hosted runner or personal Windows VM is required. It runs on pushes, published releases, and manual dispatches, builds the editor target, and packages the Windows client mod for Satisfactory (including Proton).

The personal copy at `wadhah101/Cartograph` is preserved and continues to use the standard `windows-2022` runner.

## Enable the paid 16-core runner

At preparation time, `wa101200` was on GitHub Free and the larger-runner API reported that hosted runners were not supported for the organization. This prevents provisioning the requested runner; changing the workflow label alone cannot bypass the restriction.

1. Enable an eligible plan (GitHub Team or Enterprise Cloud) and payment information for the organization. Configure an Actions spending budget that permits paid runs. Larger runners are billed per minute even for public repositories.
2. With an organization-owner GitHub CLI login authorized to manage hosted runners and runner groups, run `python scripts/setup-hosted-runner.py`. The CLI token may need the classic `manage_runners:org` and `admin:org` scopes (or equivalent fine-grained permissions).
3. The script discovers machine/image IDs, creates a runner group restricted to this repository, provisions the 16-core runner with maximum concurrency **one**, and sets `WINDOWS_16_CORE_READY=true` once it is Ready. If it is still provisioning, re-run the script after it becomes Ready.
4. Manually start `Build Cartograph` in Actions. Until readiness is enabled, a small standard Linux job reports the setup requirement and prevents the Windows build from sitting in an endless queue.

Alternatively, configure the same named runner in **Organization Settings → Actions → Runners → New GitHub-hosted runner**, grant this repository access, and set the readiness variable after it is Ready. Choose Windows **x64**, not ARM64.

## Required Actions secrets

Under **Settings → Secrets and variables → Actions → Secrets**, add:

- `CSS_ENGINE_TOKEN`: a GitHub token from an account authorized to read `satisfactorymodding/UnrealEngine`. The workflow downloads the custom CSS Unreal Editor. This repository's default `GITHUB_TOKEN` cannot access that separate private repository.
- `WWISE_EMAIL` and `WWISE_PASSWORD`: credentials for an authorized Audiokinetic account. The workflow downloads Wwise SDK `2023.1.14.8770` and integrates Unreal plugin version `2023.1.14.3555` using `wwise-cli`.

These licensed dependencies cannot be downloaded without the relevant access. Do not commit credentials, engine files, or Wwise files to the repository.

Optionally set the **Actions variable** `CSS_ENGINE_RELEASE` to the engine release tag for `5.6.1-CSS`. Otherwise the latest release is used. The workflow rejects engine versions other than 5.6.1.

## Downloading the build

Open **Actions → Build Cartograph**, select a successful run, and download `Cartograph-Windows-<run>` under **Artifacts**. Artifacts are retained for 90 days. Published-release builds upload Actions artifacts, not release attachments.

## Build limits

The 16-core runner provides substantially more disk and RAM than a standard runner, but download, extraction, and compilation must still fit the six-hour job timeout. This configuration has not yet completed a build. CPU count alone does not fix toolchain or source-code errors.
