# Building Cartograph in GitHub Actions

The `Build Cartograph` workflow builds the Windows client package and uploads it as a downloadable Actions artifact when a commit is pushed, a GitHub release is published, or the workflow is started manually.

## Runner requirements

This project uses Coffee Stain's custom Unreal Engine (`5.6.1-CSS`) and Wwise. These licensed dependencies are not included in this repository, and the engine is too large for the storage available on a standard GitHub-hosted Windows runner. The workflow therefore targets a **self-hosted Windows x64 runner** with the label `satisfactory-mod-builder`.

Install and configure the runner as a Windows service on a Windows VM with:

- the custom Unreal Engine CSS 5.6.1 editor installed (the default path is `C:\Program Files\Unreal Engine - CSS`);
- the matching Visual Studio C++ toolchain and Windows SDK required by that engine;
- the project-integrated Wwise plugin for the Wwise version required by this branch.

The engine must be obtained through the Satisfactory Modding project's authorized distribution. The Wwise plugin must be installed in accordance with its license. Do not commit either dependency to this repository.

## Repository variables

In **Settings → Secrets and variables → Actions → Variables**, optionally set:

- `UE_CSS_ROOT`: Unreal Engine CSS installation directory, if it is not at the default path above.
- `WWISE_PLUGIN_PATH`: path to the Wwise plugin folder containing `Wwise.uplugin`. The workflow copies it into the checkout before building.
- `WWISE_NIAGARA_PLUGIN_PATH`: optional path to the WwiseNiagara plugin folder containing `WwiseNiagara.uplugin`. If omitted, the workflow looks for a sibling `WwiseNiagara` folder next to `WWISE_PLUGIN_PATH`.

After the workflow succeeds, download `Cartograph-Windows-<run>` from the run's **Artifacts** section. The resulting Windows client package is appropriate for the Windows build of Satisfactory running under Proton.
