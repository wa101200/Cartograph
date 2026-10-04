# Native Linux/Wine build

Local builds run directly on Linux using Wine/MSVC. **Docker is not used.**

```bash
./scripts/build-local.sh --check
./scripts/build-local.sh
JOBS=4 ./scripts/build-local.sh  # Default: all available CPU threads
```

Output:

```text
Saved/ArchivedPlugins/Cartograph/Cartograph-Windows.zip
```

The script builds the Linux editor, then packages the **Windows Steam mod** for Satisfactory/Proton. It does not install the mod or launch the game.

## Dependencies

- Host Wine, Python 3, GitHub CLI, msitools (`msiextract`), patch and dos2unix.
- CSS Unreal Engine **5.6.1-CSS** Linux editor.
- MSVC **17.8 / 14.38**, Windows SDK **10.0.22621**, patched `msvc-wine` wrappers and PDBCopy.
- Integrated Wwise SDK **2023.1.14.8770** / plugin integration **2023.1.14.3555** in `Plugins/Wwise` and `Plugins/WwiseNiagara`.

The existing host toolchains on this machine were retained and the native smoke test passed with Wine **11.12**, MSVC **19.38**, and .NET **8.0.300**.

Default paths under `~/.local/share/cartograph-build`:

| Path | Contents |
| --- | --- |
| `ue/` | Native CSS engine, including required precompiled rule assemblies |
| `msvc/` | Installed MSVC/Windows SDK/PDBCopy |
| `tools/` | User-local host tools extracted for Manjaro |
| `wine-prefix/` | Isolated native-build Wine prefix, not host `.wine` or Proton |
| `cache/`, `nuget/`, `ddc/`, `tmp/` | Native build caches and temporary files |

Overrides: `CARTOGRAPH_BUILD_ROOT`, `UE_CSS_ROOT`, `UE_WINE_MSVC`, `WINEPREFIX`, `JOBS`, `CARTOGRAPH_CACHE_HOME`, `CARTOGRAPH_TMPDIR`, `CARTOGRAPH_DDC`, `NUGET_PACKAGES`.

Engine registration, when needed for Wwise integration, uses `scripts/register-engine.py` to write `Install.ini` directly. No graphical selector or modal dialogs are launched.

UBA and debug information are disabled, and cooking uses `InstalledNoZenLocalFallback` with a writable filesystem DDC. UBT configuration is only rewritten when its contents change and unrelated options are preserved.

## Cleanup

The Docker experiment, isolated daemon/storage, temporary test copies, duplicate Wwise download cache and generated compiler outputs were removed. Integrated SDK libraries, host engine/MSVC tools, the packaged ZIP and installed mods were preserved. The next build will recompile the removed outputs; missing download caches can be downloaded again if integration is required later.
