#!/usr/bin/env python3
"""Provision the org's paid Windows x64 runner using an authorized gh login.

Run after enabling an eligible org plan and billing. Requires gh with runner
administration permissions. Maximum concurrency is one to constrain spending.
Re-run once the runner reports Ready to enable the workflow readiness variable.
"""

import json
import subprocess

ORG = "wa101200"
REPO = f"{ORG}/Cartograph"
NAME = "cartograph-windows-64core"


def api(path, payload=None):
    args = ["gh", "api", path]
    if payload is not None:
        args += ["--method", "POST", "--input", "-"]
    result = subprocess.run(
        args,
        input=json.dumps(payload) if payload is not None else None,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise SystemExit(
            f"GitHub request failed: {path}\n{result.stderr}\n"
            "Check the organization plan, billing, and runner-administration permissions."
        )
    return json.loads(result.stdout)


def main():
    base = f"orgs/{ORG}/actions"
    runners = api(f"{base}/hosted-runners?per_page=100")["runners"]
    runner = next((r for r in runners if r["name"] == NAME), None)
    if runner is None:
        images = api(f"{base}/hosted-runners/images/github-owned")["images"]
        image = next(
            (i for i in images if i["platform"] == "win-x64"
             and i["display_name"] == "Windows Server 2022"), None
        )
        if image is None:
            raise SystemExit(
                "Windows Server 2022 image not available. Available images:\n"
                + json.dumps(images, indent=2)
            )
        sizes = api(f"{base}/hosted-runners/machine-sizes")["machine_specs"]
        size = next(
            (s for s in sizes if s["cpu_cores"] == 64 and s["memory_gb"] == 256),
            None,
        )
        if size is None:
            raise SystemExit("No 64-core / 256-GB x64 machine size is available.")
        repo_id = api(f"repos/{REPO}")["id"]
        groups = api(f"{base}/runner-groups?per_page=100")["runner_groups"]
        group = next((g for g in groups if g["name"] == NAME), None)
        if group is None:
            group = api(
                f"{base}/runner-groups",
                {
                    "name": NAME,
                    "visibility": "selected",
                    "selected_repository_ids": [repo_id],
                    "allows_public_repositories": True,
                },
            )
        runner = api(
            f"{base}/hosted-runners",
            {
                "name": NAME,
                "image": {"id": image["id"], "source": "github"},
                "size": size["id"],
                "runner_group_id": group["id"],
                "maximum_runners": 1,
                "enable_static_ip": False,
            },
        )
    specs = runner["machine_size_details"]
    if runner["platform"] not in ("win-x64", "windows-x64") or specs["cpu_cores"] != 64 or specs["memory_gb"] != 256:
        raise SystemExit("The existing runner is not the requested Windows x64 64-core / 256-GB runner.")
    if runner.get("maximum_runners") != 1:
        raise SystemExit("Existing runner concurrency must be set to one before enabling builds.")
    print(f"{NAME}: {runner['status']}; specs: {specs}")
    if runner["status"] != "Ready":
        print("Provisioning is not complete. Re-run this script once the runner is Ready.")
        return
    subprocess.run(
        ["gh", "variable", "set", "WINDOWS_64_CORE_READY", "--repo", REPO, "--body", "true"],
        check=True,
    )
    print("64-core builds enabled. Start Build Cartograph from the Actions page.")


if __name__ == "__main__":
    main()
