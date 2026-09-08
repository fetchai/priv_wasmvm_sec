# Confidential Security Hotfix

⚠️ **This repository is confidential.**

This repository contains a **private security hotfix for a critical severity CosmWasm vulnerability** that can lead to **fund loss**. The issue is exploitable in practice, and has been locally reproduced.

The vulnerability is in the Wasmer Singlepass compiler used by `libwasmvm`. The fix upgrades the embedded Wasmer engine to **7.4.0**. Any chain that links `libwasmvm` and allows contract upload or instantiation to be reached by an attacker is affected.

Details are intentionally limited during the private disclosure window.
Please **do not share, fork, or discuss publicly** until disclosure.

Thank you for your continued dedication to maintaining a safe and secure ecosystem.

---

## Upgrade Guidance

To reduce the risk of premature disclosure, it is **strongly recommended** that this fix is deployed via **compiled binaries distributed directly to validators**, rather than public source changes, until the disclosure window closes.

This upgrade must be performed as a coordinated upgrade.

If you cannot complete this upgrade before the disclosure window closes, apply the interim mitigation instead: rebuild your existing binary as position-independent (`-buildmode=pie`, and `-static-pie` in place of `-static` in `extldflags`) and set `kernel.randomize_va_space=2` on every validator host. That reduces exploitability but does not remove the vulnerability.

## Timeline

The private disclosure window for this vulnerability is open now. After the window closes, the fixes will be merged into the public repositories and released as patch releases.

⚠️ **Disclosure date: [NEEDS CONFIRMING before this doc is shared]**

### Hotfix Branches

The fix is delivered on `security/*` branches. Pick the one matching your current `wasmvm` line. **The Go module path differs by major version, so the two are not interchangeable.**

| Your `wasmvm` line | Branch | Version | Module path | Previous Wasmer | Patched Wasmer |
|---|---|---|---|---|---|
| `v2.3.x` | `security/v2.3.x` | `2.3.5-rc.2` | `github.com/CosmWasm/wasmvm/v2` | 4.3.7 | **7.4.0** |
| `v3.0.x` | `security/v3.0.x` | `3.0.8-rc.2` | `github.com/CosmWasm/wasmvm/v3` | 5.0.6 | **7.4.0** |

Tag status:

- `v2.3.5-rc.2` is tagged and resolvable.
- ⚠️ **`v3.0.8-rc.2` is not yet tagged.** Pin by commit from the head of `security/v3.0.x` until a tag is published.

> If you are on a `wasmvm` line older than `v2.3.x`, there is no patched branch for you. Contact us. Do not attempt to port the fix yourself. Apply the PIE and ASLR mitigation above in the meantime.

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

Add a `replace` directive pointing to this repository, using the module path and version that match your release line.

If you are on `v2.3.x`:

```go
replace github.com/CosmWasm/wasmvm/v2 => github.com/CosmWasm/priv_wasmvm_sec v2.3.5-rc.2
```

If you are on `v3.0.x`:

```go
replace github.com/CosmWasm/wasmvm/v3 => github.com/CosmWasm/priv_wasmvm_sec <commit-sha>
```

Take `<commit-sha>` from the head of `security/v3.0.x`.

Then, tidy using the `GOPRIVATE` variable:

```bash
GOPRIVATE=github.com/CosmWasm/priv_wasmvm_sec go mod tidy
```

> If you also consume `wasmd`, use the private `wasmd` repository as well and replace both. See https://github.com/CosmWasm/priv_wasmd_sec.

### 3. Verify you picked up the fix

Prebuilt shared libraries are committed to this repository, so a Rust toolchain is not required for a standard build:

- `internal/api/libwasmvm.x86_64.so`
- `internal/api/libwasmvm.aarch64.so`
- `internal/api/libwasmvm.dylib`

Confirm the resolved version, and confirm the library is position-independent:

```bash
go list -m github.com/CosmWasm/wasmvm/v2   # or /v3
readelf -h internal/api/libwasmvm.x86_64.so | grep Type   # expect DYN
```

If you rebuild `libwasmvm` from source instead, build it with PIC.

---

### 4. Build and Deploy

Rebuild your node binary using your standard process, distribute the compiled binary to validators, and perform a coordinated upgrade.

Build the binary as position-independent so that ASLR applies:

```bash
-buildmode=pie
# and, if you build statically, use -static-pie rather than -static in extldflags
```

Set `kernel.randomize_va_space=2` on every validator host. Confirm the resulting binary is position-independent before distributing it:

```bash
readelf -h ./build/<your-binary> | grep Type   # expect DYN
```

---

## Notes

- Do not mirror this repository to public infrastructure
- Do not copy this repository to a public Github repository
- Do not reference this fix in public changelogs or releases before disclosure
- Do not publish the patched binary's build instructions or version string ahead of disclosure. A version string that does not correspond to any public tag identifies a chain as carrying a private security build.
