# Using bitsnbites/playwright in your CI

> **Heads-up:** this image ships **Chromium only**. Wolfi (the hardened base) doesn't include the GTK/libsoup/libwayland deps Firefox and WebKit need. If you need cross-browser E2E, use `mcr.microsoft.com/playwright` for those suites.

## 1. Drop-in replacement for `setup-node` + `playwright install`

```yaml
jobs:
  e2e:
    runs-on: ubuntu-latest
    container: ghcr.io/shared-stash/playwright:1.59-node24
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm exec playwright test
```

## 2. Build job (no Playwright needed, but you still want fast Node + pnpm)

The same image works for plain build jobs — Node, pnpm, yarn, and the native module toolchain are all preinstalled.

```yaml
jobs:
  build-web:
    runs-on: ubuntu-latest
    container: ghcr.io/shared-stash/playwright:1.59-node24
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - uses: actions/upload-artifact@v4
        with: { name: web-dist, path: dist }
```

## 3. Cross-version matrix

Useful while upgrading Playwright or Node — run the suite against multiple combos in parallel.

```yaml
jobs:
  e2e:
    strategy:
      fail-fast: false
      matrix:
        image:
          - ghcr.io/shared-stash/playwright:1.59-node24
          - ghcr.io/shared-stash/playwright:1.58-node24
          - ghcr.io/shared-stash/playwright:1.59-node22
    runs-on: ubuntu-latest
    container: ${{ matrix.image }}
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm exec playwright test
```

## 4. Pinning to an exact patch

If you want full reproducibility, use the patch-pinned tag.

```yaml
container: ghcr.io/shared-stash/playwright:1.59.1-node24
```

## 5. Docker Hub mirror

Same image, mirrored to the `bitsnbites010` namespace on Docker Hub.

```yaml
container: bitsnbites010/playwright:1.59-node24
```

## 6. Self-hosted arm64 runners

The image is multi-arch (`amd64` + `arm64`) — the same tag works on both. No change needed.

## 7. What about `actions/cache`?

You still want it for `node_modules` / pnpm store / Playwright test artifacts. The image only saves time on browser + system-dep installation, not on your project's deps.

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.local/share/pnpm/store
    key: pnpm-${{ hashFiles('pnpm-lock.yaml') }}
```

## Heads-up: deprecated tags

If you see a tag with a `-deprecated` suffix in the registry, or your pulls log a deprecation annotation, that combo is on a 90-day countdown to deletion. Move to a supported combo before then. The supported set is regenerated nightly from [endoflife.date](https://endoflife.date/nodejs).
