# Linux/Wine build experiment

`Build Cartograph (Linux Wine)` is independent of the native Windows workflow and uses **`blacksmith-16vcpu-ubuntu-2404`** (16 vCPU, 64 GB RAM, 750 GB disk).

It follows [Satisfactory Mod Loader's current Linux CI](https://github.com/satisfactorymodding/SatisfactoryModLoader/blob/master/.github/workflows/build.yml):

1. Build Wine 11 with the same oleaut32 typelib patch used upstream.
2. Install MSVC 17.8 and Windows SDK 10.0.22621 using the patched `msvc-wine` scripts.
3. Download and register the Linux CSS Unreal Engine, integrate Wwise, and compile the Linux editor.
4. Cross-compile/package **the Windows client mod**, using Wine for the MSVC tools.
5. Upload `Cartograph-Windows-Wine-<run>` as an Actions artifact.

This produces a Windows package suitable for Satisfactory under Proton, not a native Linux game-client mod. The same three repository secrets and pinned `CSS_ENGINE_RELEASE` used by Windows CI are reused. Proprietary engine and toolchain files are not published as caches.

The workflow runs on push, published release, and manual dispatch. Its concurrency group is separate from the Windows workflow. Wine compilation adds setup time; this is an experimental alternative, not yet a verified successful build.
