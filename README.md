# Confidential Security Hotfix

⚠️ **This repository is confidential.**

This repository contains a **private security hotfix for a critical severity CosmWasm vulnerability**
that can lead to **fund loss**. The issue is exploitable in practice, and has been locally reproduced.

Details are intentionally limited during the private disclosure window.
Please **do not share, fork, or discuss publicly** until disclosure.

Thank you for your continued dedication to maintaining a safe and secure ecosystem.

---

## Upgrade Guidance

Build the binary yourself and hand the compiled binary to your validators.
Do not publish the source change, and do not point validators at this repository,
until the disclosure window closes.

Perform the upgrade as a coordinated upgrade.

## Timeline

The private disclosure window for this vulnerability is 2 weeks, beginning Thursday, September 10th.
After the disclosure window closes, the fixes will be merged into the public repo
at 10am EST on Thursday, September 24th 2026 and released in a patch release.

### Hotfix Tags

Use the tag matching your release line. `main` tracks upstream and does not contain the fix.

| Your release line | Tag             | Branch             | wasmvm replacement                                   |
|-------------------|-----------------|--------------------|------------------------------------------------------|
| `v0.54.x`         | `v0.54.10-rc.3` | `security/v0.54.x` | `github.com/CosmWasm/priv_wasmvm_sec/v2 v2.2.9-rc.3` |
| `v0.60.x`         | `v0.60.9-rc.3`  | `security/v0.60.x` | `github.com/CosmWasm/priv_wasmvm_sec/v2 v2.3.5-rc.3` |
| `v0.61.x`         | `v0.61.15-rc.3` | `security/v0.61.x` | `github.com/CosmWasm/priv_wasmvm_sec/v3 v3.0.8-rc.3` |
| `v0.70.x`         | `v0.70.4-rc.3`  | `security/v0.70.x` | `github.com/CosmWasm/priv_wasmvm_sec/v3 v3.0.8-rc.3` |

Chains on a release line not listed above should upgrade to the closest version that is.

#### Static library checksums

The `libwasmvm_muslc.<arch>.a` extracted from the private wasmvm module must match one of these sha256 values.
See step 3 below.

| wasmvm        | `x86_64`                                                           | `aarch64`                                                          |
|---------------|--------------------------------------------------------------------|--------------------------------------------------------------------|
| `v2.2.9-rc.3` | `c2e4018d532138fad3113a140ccb6c73cfa41b5c9889633b08299e59568616b9` | `0b52937b401b5595232c91ab98e4645f5fdcc86220105a6eab60eba938cf8f46` |
| `v2.3.5-rc.3` | `8916669b44e4a88b044f97ae7cd27feacdcfa205f494f91eecea7428968193b5` | `6f1330191109b99ad6917cd8dec318b04ca660d9853b4e182f9bcd76b0392038` |
| `v3.0.8-rc.3` | `ab1a878ed3beecc5f3821b1fb1f73a5254443e3ba9bca53964a50a122ee77497` | `cc9175235d1e0051002c33a94027a63a008b14dcc13ae483685e511d59754235` |

The `-rc.3` suffix is intentional and is the tag to use. These stay as release candidates
for the duration of the private window so the correct version is easy to identify
and a further hotfix can be added without renumbering.
The final tags are published, without version holes, only after the disclosure window closes.

---

## Applying the Hotfix

### 1. Update your Git config to use private repositories

#### SSH Instructions

First, configure your machine to use SSH for Git.
More details can be found here: https://docs.github.com/en/authentication/connecting-to-github-with-ssh.

To use SSH in `go mod` downloads, add these lines to `~/.gitconfig`:

```md
[url "ssh://git@github.com/"]
    insteadOf = https://github.com/
```

#### HTTPS Instructions

If you choose to use HTTPS, please follow the instructions here: https://go.dev/doc/faq#git_https.

### 2. Update `go.mod`

Add `replace` directives for both this repository and the private `wasmvm` repository,
using the tag and wasmvm dependency from the table above.

For example, if you are on `v0.60.x`:

```go
replace (
	github.com/CosmWasm/wasmd => github.com/CosmWasm/priv_wasmd_sec v0.60.9-rc.3
	github.com/CosmWasm/wasmvm/v2 => github.com/CosmWasm/priv_wasmvm_sec/v2 v2.3.5-rc.3
)
```

Two directives are required: the patched `wasmd` depends on a `wasmvm` version that is available
only in the private `wasmvm` repository.

The `/v2` or `/v3` suffix appears on **both sides** of the `wasmvm` directive and is required on both.
It is `/v2` for the `v0.54.x` and `v0.60.x` lines and `/v3` for the `v0.61.x` and `v0.70.x` lines.
Omitting it on the right-hand side fails with `version "v2.3.5-rc.3" invalid: should be v0 or v1, not v2`.

Then export `GOPRIVATE` and tidy:

```shell
export GOPRIVATE=github.com/CosmWasm/priv_wasmd_sec,github.com/CosmWasm/priv_wasmvm_sec
go mod tidy
```

Keep `GOPRIVATE` exported for the build as well. Build targets such as `make build` re-run `go mod tidy`
and `go mod download` internally, and without it Go tries to verify these modules against
the public checksum database and fails with `verifying go.mod: ... sum.golang.org/lookup/...: 404 Not Found`.

---

### 3. Build and Deploy

Building from this repository is not the same as building from the public one.
Depending on whether you link `libwasmvm` dynamically or statically, your build script or Dockerfile
will need changes; do not assume your existing build target works unchanged.

Before you build, check your Dockerfile and Makefile for anything that derives the wasmvm
version by reading `go.mod`, for example
`WASMVM_VERSION=$(cat go.mod | grep github.com/CosmWasm/wasmvm/vN | awk '{print $2}')`.
The `replace` directive adds a second line matching that pattern, so the grep returns two
values instead of one and the version comes out malformed. Remove or hardcode that step. The
public release asset it fetches does not exist for these tags in any case.

In the two commands below, replace `vN` with `/v2` or `/v3` to match your line from the table above.

**Dynamic build on the host** (`make build`): keep `GOPRIVATE` exported and build as usual.
Ship the patched `libwasmvm.<arch>.so` with the binary and have validators install it in place of the public one:

```shell
cp "$(go list -m -f '{{.Dir}}' github.com/CosmWasm/wasmvm/vN)/internal/api/libwasmvm.$(uname -m).so" .
```

**Static build in Docker** (e.g. `make build-static-linux-amd64`): two changes are needed.

1. On the host, after step 2, copy the two private modules into the build context:

```shell
go mod download
mkdir -p .modcache/github.com/\!cosm\!wasm
cp -r "$(go env GOMODCACHE)"/cache/download/github.com/\!cosm\!wasm/priv_wasmd_sec \
      "$(go env GOMODCACHE)"/cache/download/github.com/\!cosm\!wasm/priv_wasmvm_sec \
      .modcache/github.com/\!cosm\!wasm/
```

2. In the Dockerfile, replace the `go mod download` step and the `ADD` of the wasmvm
   release asset (plus any `cp` of it) with the block below. Use `/v2` or `/v3` to match your line,
   and the checksums from the table above:

```dockerfile
COPY .modcache/ /modcache/
ENV GOPROXY=file:///modcache,https://proxy.golang.org,direct
RUN go mod download
RUN apk add --no-cache xz \
 && unxz -c "$(go list -mod=readonly -m -f '{{.Dir}}' github.com/CosmWasm/wasmvm/vN)/internal/api/libwasmvm_muslc.$(uname -m).a.xz" \
      > "/lib/libwasmvm_muslc.$(uname -m).a"
RUN sha256sum "/lib/libwasmvm_muslc.$(uname -m).a" | grep -E "<x86_64 sha256>|<aarch64 sha256>"
```

Do not commit `.modcache/`, and make sure `.dockerignore` does not exclude it.
If your Dockerfile already sets `GOPROXY` or mounts a cache on `/go/pkg/mod`,
keep your `GOPROXY` entries after the `file://` one and put the cache mount on the `unxz` line too.

Once built, distribute the compiled binary, plus the shared library for dynamic builds,
to your validators. On each node, `<binary> query wasm libwasmvm-version` must print the wasmvm version
from the table before the coordinated upgrade.

---

## Notes

- Do not mirror this repository to public infrastructure
- Do not copy this repository to a public Github repository
- Do not reference this fix in public changelogs or releases before disclosure
