# docker-backstage

Shared dependency base image for [app-backstage](https://github.com/mattjmorrison-homelab/app-backstage). This repo is the sole authoritative source for Backstage's dependency files (`package.json`, `yarn.lock`, `.yarnrc.yml`, `.yarn/`, `backstage.json`, and the app/backend workspace `package.json`s) -- app-backstage no longer keeps its own copies.

Its `Dockerfile` publishes two independent targets so `app-backstage`'s CI doesn't have to repeat a ~747MB, 1700+-package `yarn install` on every PR:

- `prod` -- production dependencies only (`yarn workspaces focus backend --production`). The runtime base `app-backstage`'s release image builds from.
- `test` -- production + dev dependencies (`yarn install --immutable`), plus the native-module compiler toolchain (python3/make/g++). What `app-backstage`'s build stage (tests, `tsc`, `build:backend`) builds on top of.

Both publish to the internal Zot registry as `registry.morrisons.site/docker-backstage:prod` and `registry.morrisons.site/docker-backstage:test` on every merge to `main`.