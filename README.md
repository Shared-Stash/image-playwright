# bitsnbites/playwright

A hardened Playwright Docker image for GitHub Actions, sized to make `Build Web` and `E2E Tests` jobs faster on React / Angular / Node projects. Built nightly. **For tests and builds, not for deploys.**

## What's inside

| | |
|---|---|
| Base | `cgr.dev/chainguard/wolfi-base` (Chainguard hardened) |
| Node | latest Active LTS — currently **24** |
| Playwright | one image per supported minor (latest 3) |
| Browsers | **Chromium only** (Firefox + WebKit deps are not in Wolfi — see note below) |
| Package managers | `npm`, `pnpm`, `yarn` |
| CLI essentials | `git`, `curl`, `jq`, `bash`, `ca-certificates`, `tzdata` |
| Native build chain | `python3`, `make`, `gcc`, `g++`, `pkgconf` |
| Architectures | `linux/amd64`, `linux/arm64` |

The slow steps that this image removes from your CI:

| step | typical cost | here |
|---|---|---|
| `npx playwright install chromium` | 20–30s | already done |
| `npx playwright install-deps` | 30s+ | already done |
| `npm i -g pnpm yarn` | 10–20s | already done |
| `apt-get install` for `node-gyp` deps | 10s+ | already done |

### Why Chromium only?

The base image is `cgr.dev/chainguard/wolfi-base` — Chainguard's hardened, minimalist distro. Wolfi intentionally does **not** ship GTK, libsoup, libwayland-*, libhyphen, libmanette, libgudev, dbus-glib, or several other libraries that Firefox and WebKit need at runtime (these libs are CVE-prone and excluded by design).

So you have a fork in the road if you need cross-browser E2E:

- For Chromium-only suites (the majority of teams), this image is the smallest, most-hardened option and works out of the box.
- For Firefox or WebKit suites, use [`mcr.microsoft.com/playwright`](https://mcr.microsoft.com/en-us/product/playwright) instead — Microsoft's official image is Ubuntu-based and ships all three browsers, at the cost of a larger, less-hardened base.

## Tag scheme

Tags are `:<playwright-minor>-node<node-major>`, plus a pinned `:<playwright-full>-node<node-major>` for reproducibility, plus a moving `:latest` aliasing newest-Playwright × newest-LTS-Node.

```
ghcr.io/shared-stash/playwright:1.59-node24      # latest patch of 1.59 on Node 24
ghcr.io/shared-stash/playwright:1.59.1-node24    # exact pin
ghcr.io/shared-stash/playwright:1.58-node22      # older minor + older LTS
ghcr.io/shared-stash/playwright:latest           # newest x newest
```

Mirrored to `docker.io/bitsnbites010/playwright:*` with identical tags. (The Docker Hub namespace is `bitsnbites010` — the `bitsnbites` org name only exists on GitHub.)

## Support policy

- **Node**: tracks [endoflife.date](https://endoflife.date/nodejs). The matrix is regenerated nightly and any LTS line still in support is built. Node lines that hit EOL get dropped from the active matrix and their existing tags are marked deprecated.
- **Playwright**: not on endoflife.date. We keep the **latest 3 minors** (currently 1.59, 1.58, 1.57). Older minors get marked deprecated.
- **Deprecated tags** stay pullable for **90 days** after the deprecation date (so existing pipelines don't break overnight), then they're hard-deleted from both registries.

A deprecated tag is announced two ways:

1. The manifest carries `org.opencontainers.image.deprecated=true` plus `org.bitsnbites.deprecated.at=<YYYY-MM-DD>` and `org.bitsnbites.deprecated.reason=<text>` annotations.
2. A sibling tag like `:1.55-node20-deprecated` is pushed alongside, so it's visible in every registry's tag listing.

## Using it in a workflow

Run your test/build job *inside* the image and most of the slow steps disappear.

```yaml
# .github/workflows/test.yml in your project
jobs:
  e2e:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/shared-stash/playwright:1.59-node24
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - run: pnpm exec playwright test
```

That's it — no `setup-node`, no `playwright install`, no `install-deps`.

See [`examples/usage.md`](examples/usage.md) for more patterns (matrix testing across Playwright versions, caching, Docker Hub mirror, etc.).

## How the nightly works

The nightly is a thin caller. All the heavy lifting (matrix resolution, skip-if-unchanged build, multi-arch push, deprecation, 90-day cleanup) lives in [`Shared-Stash/workflows`](https://github.com/Shared-Stash/workflows) and is shared by every CI image we publish.

This repo only contributes two files of substance:

1. **`Dockerfile`** — the actual image definition.
2. **`versions.yml`** — declares the supported matrix axes (Playwright minors from GitHub releases, Node LTS from endoflife.date) and the tag/build-arg templates. Read by `workflows/scripts/get-versions.py` on every nightly run, so the supported set is always derived live from upstream.

The nightly workflow itself is a single `uses:` of the reusable `ci-image.yml` — there is no per-image matrix-resolver script anymore.

## Required secrets

| name | purpose |
|---|---|
| `GITHUB_TOKEN` | provided automatically. Needs `packages: write` (set in workflow). |
| `DOCKERHUB_USERNAME` | Docker Hub robot account. |
| `DOCKERHUB_TOKEN` | Docker Hub access token (with read/write/delete on `bitsnbites010/playwright`). |

## Layout

```
.
├── Dockerfile
├── .dockerignore
├── versions.yml             # declarative matrix config (axes, tags, build_args)
├── .github/workflows/
│   ├── nightly.yml          # thin caller -> Shared-Stash/workflows/ci-image.yml
│   └── pr.yml               # thin caller -> Shared-Stash/workflows/pr-validate.yml
├── examples/usage.md
├── LICENSE
└── README.md
```

Everything generic (the version resolver, the skip-gate, the deprecation diff, the 90-day janitor) lives in [`Shared-Stash/workflows`](https://github.com/Shared-Stash/workflows) so the next CI image we add (`image-node`, `image-bun`, etc.) only needs its own `Dockerfile` + `versions.yml`.

## Status

This component lives in [`shared-stash`](https://github.com/Shared-Stash/shared-stash) under `image-playwright/`. The folder is structured to be split out into its own `Shared-Stash/image-playwright` GitHub repo when you're ready — `git subtree split --prefix=image-playwright -b image-playwright` and push.
