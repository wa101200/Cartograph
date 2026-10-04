# Native Linux/Wine CI

See [BUILDING.md](BUILDING.md) for setup and cache details.

CI runs directly on Blacksmith Ubuntu 24.04 x64, without Docker, using patched Wine 11, MSVC 17.8, Windows SDK 10.0.22621, the Linux CSS engine and Wwise integration. It compiles the Linux editor and cross-compiles/packages the **Windows Steam mod**.

Toolchains and generated compiler/cooker outputs remain aggressively cached on sticky disks; APT downloads are also cached. Engine registration is headless and build steps have watchdog/time limits. Native Windows CI remains removed.
