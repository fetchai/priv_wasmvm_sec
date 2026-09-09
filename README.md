# Confidential Security Hotfix

⚠️ **This repository is confidential.**

This repository contains a **private security hotfix for a critical severity CosmWasm vulnerability** that can lead to **fund loss**. The issue is exploitable in practice, and has been locally reproduced.

Details are intentionally limited during the private disclosure window.
Please **do not share, fork, or discuss publicly** until disclosure.

Thank you for your continued dedication to maintaining a safe and secure ecosystem.

---

## Upgrade Guidance

Build the binary yourself and hand the compiled binary to your validators. Do not publish the source change, and do not point validators at this repository, until the disclosure window closes.

Perform the upgrade as a coordinated upgrade.

## Timeline

The private disclosure window for this vulnerability is 2 weeks, beginning Thursday, September 10th. After the disclosure window closes, the fixes will be merged into the public repo at 10am EST on Thursday, September 24th 2026 and released in a patch release.

### Hotfix Tags

Use the tag matching your release line. `main` tracks upstream and does not contain the fix.

| Your `wasmvm` line | Tag | Branch | Module path |
|---|---|---|---|
| `v2.2.x` | `v2.2.9-rc.2` | `security/v2.2.x` | `github.com/CosmWasm/wasmvm/v2` |
| `v2.3.x` | `v2.3.5-rc.2` | `security/v2.3.x` | `github.com/CosmWasm/wasmvm/v2` |
| `v3.0.x` | `v3.0.8-rc.2` | `security/v3.0.x` | `github.com/CosmWasm/wasmvm/v3` |

The module path changes with the major version, so the `v2` and `v3` replace directives are not interchangeable.

Chains on a `wasmvm` line older than `v2.2.x` should upgrade to the closest version above.

The `-rc.2` suffix is intentional and is the tag to use. These stay as release candidates for the duration of the private window so the correct version is easy to identify and a further hotfix can be added without renumbering. The final tags are published, without version holes, only after the disclosure window closes.

---

## Applying the Hotfix

### 1. Update your Git config to use private repositories

#### SSH Instructions

First, configure your machine to use SSH for Git. More details can be found here: https://docs.github.com/en/authentication/connecting-to-github-with-ssh.

To use SSH in `go mod` downloads, add these lines to `~/.gitconfig`:

```md
[url "ssh://git@github.com/"]
    insteadOf = https://github.com/
```

#### HTTPS Instructions

If you choose to use HTTPS, please follow the instructions here: https://go.dev/doc/faq#git_https.

### 2. Update `go.mod`

Add a `replace` directive pointing to this repository, using the module path and tag that match your release line.

If you are on `v2.2.x`:

```go
replace github.com/CosmWasm/wasmvm/v2 => github.com/CosmWasm/priv_wasmvm_sec/v2 v2.2.9-rc.2
```

If you are on `v2.3.x`:

```go
replace github.com/CosmWasm/wasmvm/v2 => github.com/CosmWasm/priv_wasmvm_sec/v2 v2.3.5-rc.2
```

If you are on `v3.0.x`:

```go
replace github.com/CosmWasm/wasmvm/v3 => github.com/CosmWasm/priv_wasmvm_sec/v3 v3.0.8-rc.2
```

The `v2.2.x` and `v2.3.x` lines share the `/v2` module path but take different versions, so use the one matching your line rather than the newer of the two.

Note the `/v2` or `/v3` suffix on `priv_wasmvm_sec`. It is required. Without it Go rejects the directive with `version "v2.3.5-rc.2" invalid: should be v0 or v1, not v2`, because this repository declares a post-v1 module path.

Then export `GOPRIVATE` and tidy:

```bash
export GOPRIVATE=github.com/CosmWasm/priv_wasmvm_sec
go mod tidy
```

Keep `GOPRIVATE` exported for the build as well. Build targets such as `make build` re-run `go mod tidy` and `go mod download` internally, and without it Go tries to verify these modules against the public checksum database and fails with `verifying go.mod: ... sum.golang.org/lookup/...: 404 Not Found`.

If you also consume `wasmd`, use the private `wasmd` repository as well: https://github.com/CosmWasm/priv_wasmd_sec.

---

### 3. Build and Deploy

Building from this repository is not the same as building from the public one. Depending on whether you link `libwasmvm` dynamically or statically, your build script or Dockerfile will need changes. Separate build instructions covering both cases are being provided; do not assume your existing build target works unchanged.

Once built, distribute the compiled binary to your validators and perform a coordinated upgrade.

---

## Notes

- Do not mirror this repository to public infrastructure
- Do not copy this repository to a public Github repository
- Do not reference this fix in public changelogs or releases before disclosure
