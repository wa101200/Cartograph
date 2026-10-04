# Linux/Wine build experiment

`Build Cartograph (Linux Wine)` is independent of the native Windows workflow and defaults to **`blacksmith-32vcpu-ubuntu-2404`** (32 vCPU, 128 GB RAM, 1.5 TB disk). Blacksmith's published standard catalog and the organization's registered labels stop at 32 vCPU; a standard 64-vCPU label is not confirmed. If a custom larger runner is provisioned, set the repository variable `CARTOGRAPH_LINUX_RUNNER` to its actual label. Do not invent a 64-vCPU label: jobs will queue without a matching runner.

It follows [Satisfactory Mod Loader's current Linux CI](https://github.com/satisfactorymodding/SatisfactoryModLoader/blob/master/.github/workflows/build.yml):

1. Install signed, prebuilt WineHQ 11.19 packages for Ubuntu 24.04. No Wine compilation takes place.
2. Install MSVC 17.8 and Windows SDK 10.0.22621 using the patched `msvc-wine` scripts.
3. Download and register the Linux CSS Unreal Engine, integrate Wwise, and compile the Linux editor.
4. Cross-compile/package **the Windows client mod**, using Wine for the MSVC tools.
5. Upload `Cartograph-Windows-Wine-<run>` as an Actions artifact.

This produces a Windows package suitable for Satisfactory under Proton, not a native Linux game-client mod. The same three repository secrets and pinned `CSS_ENGINE_RELEASE` used by Windows CI are reused. Proprietary engine and toolchain files are not published as caches.

The workflow runs on push, published release, and manual dispatch. Its concurrency group is separate from the Windows workflow. SML's source-built Wine includes a specific oleaut32 typelib patch; the stock WineHQ package is not guaranteed to include it. This experiment tests whether the prebuilt version suffices for command-line compilation and packaging, and does not claim full Unreal Editor/Visual Studio integration compatibility. No automatic source-build fallback is used.
