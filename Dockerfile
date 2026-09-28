# Shared dependency base for app-backstage. Extracted out of
# app-backstage's own Dockerfile so its ~747MB / 1700+-package yarn
# install (plus native module compiles) happens here -- in a repo that
# changes rarely -- instead of on every app-backstage PR.
#
# common installs nothing itself; it just gets the workspace manifests
# in place so `prod` and `test` can each run their own yarn install
# without repeating the COPY/apt-get setup. Two independent published
# targets, not one chained through the other, so a `docker build
# --target=X` pull of either doesn't drag in the other's install:
#
#   prod -- production deps only (mirrors app-backstage's `release`
#           stage requirements). This becomes the runtime base
#           app-backstage builds its release image from.
#   test -- production + dev deps, plus the native-module compiler
#           toolchain (tree-sitter, esbuild, @swc/core, etc). This is
#           what app-backstage's build stage (tests, tsc, build:backend)
##          builds on top of.
#
# Both stay on node:24-trixie-slim, matching app-backstage's own base --
# the non-slim bookworm image bundles ~619MB of build tooling nothing
# here needs pre-installed; test adds its own compiler toolchain
# explicitly instead.
FROM node:24-trixie-slim AS common
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN corepack enable
COPY package.json yarn.lock .yarnrc.yml backstage.json ./
COPY .yarn ./.yarn
# Yarn needs each workspace's own package.json to know the workspaces
# exist at all -- without this, workspace-aware installs like
# `yarn workspaces focus` can't resolve packages/backend.
COPY packages/app/package.json ./packages/app/package.json
COPY packages/backend/package.json ./packages/backend/package.json

FROM common AS prod
# Only backend's own production deps -- app-backstage's release image
# serves the frontend's pre-bundled static output, it never runs
# packages/app's own React/MUI tree as live node_modules.
RUN yarn workspaces focus backend --production

FROM common AS test
# Only test needs a compiler toolchain -- for devDependency-only native
# modules (tree-sitter x2, ssh2/cpu-features, esbuild, @swc/core). prod
# never sees this; it doesn't leak into the runtime base.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends python3 make g++ && \
    rm -rf /var/lib/apt/lists/*
RUN yarn install --immutable
