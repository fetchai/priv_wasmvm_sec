# Confidential Security Hotfix

⚠️ **This repository is confidential.**

This repository contains a **private security hotfix for a critical severity CosmWasm vulnerability** that can lead to **fund loss**. The issue is exploitable in practice and has been reproduced end to end against an official release binary.

The same upgrade also carries fixes for several **high severity** vulnerabilities, which are resolved by the same Wasmer engine upgrade. Apply it as one change.

The vulnerability is in the Wasmer Singlepass compiler used by `libwasmvm`. The fix upgrades the embedded Wasmer engine to **7.4.0**. Any chain that links `libwasmvm` and allows contract upload or instantiation to be reached by an attacker is affected.

Details are intentionally limited during the private disclosure window.
Please **do not share, fork, or discuss publicly** until disclosure.

Thank you for your continued dedication to maintaining a safe and secure ecosystem.

---

## Upgrade Guidance

To reduce the risk of premature disclosure, it is **strongly recommended** that this fix is deployed via **compiled binaries distributed directly to validators**, rather than public source changes, until the disclosure window closes.

This upgrade must be performed as a coordinated upgrade.

If you cannot complete this upgrade before the disclosure window closes, the interim options below raise the bar but **do not fix the vulnerability**. Treat them as defence in depth, not remediation.

1. **Restrict `code_upload_access` from `Everybody` to a governance-controlled permission.** This is the stronger of the two. It prevents new permissionless delivery of a malicious contract. It does **not** neutralise malicious code that may already have been stored on your chain, so audit your existing stored codes as well.

2. **Rebuild as position-independent and enable ASLR**: `-buildmode=pie`, and `-static-pie` in place of `-static` in `extldflags`, plus `kernel.randomize_va_space=2` on every validator host.

⚠️ **On the PIE and ASLR mitigation specifically.** The researcher who reported this evaluated a `-static-pie` build and re-ran the exploit against it successfully, creating stake without debiting the sender across a four-validator test, with the result persisting across restart. Their assessment is that it "does not fix the underlying Wasmer Singlepass vulnerability" and that "the attacker-controlled native stack drift and JIT control-flow takeover remain intact."

The reason it still helps is narrower than it looks: their calibration relied on reading `/proc/PID/maps` as a local address oracle, which is not a remote capability. Replacing it would, in their words, "constitute new exploit development beyond the submitted PoC." So PIE and ASLR do meaningfully raise the cost of the known payload, and they are worth applying today, but do not report a PIE rebuild as remediation.

## Timeline

The private disclosure window for this vulnerability is open now. After the window closes, the fixes will be merged into the public repositories and released as patch releases.

⚠️ **Disclosure date: [NEEDS CONFIRMING before this doc is shared]**

### Hotfix Branches

⚠️ **The fix is not on `main`.** `main` tracks upstream. The patched code lives on the `security/*` branches below. Check out the branch matching your release line before you build.

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

⚠️ **Verify the fix, not the version number.** The upstream Wasmer change that corrects this appears to have fixed it incidentally during a broader refactor rather than as a targeted security patch. The researcher's explicit recommendation is that the chosen version "should be verified with a dedicated regression test rather than relying only on its version number." Do not treat a Wasmer version bump alone as proof you are patched.

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

## Am I affected?

At the reachability level the conditions are an execution stack embedding the affected Wasmer Singlepass compiler, **and** permissionless upload and execution of untrusted contracts. Exact exploit constants differ by binary, architecture and runtime layout, so a chain should not conclude it is safe because a published proof of concept does not run against its binary unchanged.

---

## Notes

- Do not mirror this repository to public infrastructure
- Do not copy this repository to a public Github repository
- Do not reference this fix in public changelogs or releases before disclosure
- Do not publish the patched binary's build instructions or version string ahead of disclosure. A version string that does not correspond to any public tag identifies a chain as carrying a private security build.

---

## Upstream documentation

This README has been replaced with the hotfix instructions because that is what you need here. The upstream project README and full build documentation are at https://github.com/CosmWasm/wasmvm.
