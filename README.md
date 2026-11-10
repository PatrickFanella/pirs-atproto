# pirs-atproto

A fork of [Bluesky's AT Protocol implementation](https://github.com/bluesky-social/atproto)
that adds one hook to the PDS package for
[Pirs](https://github.com/subculture-collective/pirs), an experiment in making an
AT Protocol personal data server extensible. It exists so Pirs can build a
pinned, patched `@atproto/pds` package. It is experimental and is not published
to npm.

Everything else is upstream code, kept as close to upstream as possible. Package
names, licenses and documentation remain attributed to their original authors.

## What the fork changes

`packages/pds` exports a `PdsHooks` type with one optional field,
`xrpcMiddleware`: a list of Express request handlers that run under `/xrpc`
after CORS and the well-known routes, before the XRPC router. Pass it as the
`hooks` argument to `PDS.create`, `PDS.fromEnv` or `PDS.run`. The handlers are
trusted transport adapters; Pirs runs plugin code in a separate process, never
inside the PDS. `packages/pds/tests/pirs-hooks.test.ts` covers a routed XRPC
method through the hook.

The hook contract and the plugin host are documented in the
[Pirs repository](https://github.com/subculture-collective/pirs).

## Quick start

You need Node.js 22 or later (`.nvmrc` pins 24) and pnpm. Tests need Docker
for PostgreSQL and Redis.

```sh
pnpm install --frozen-lockfile
pnpm build
pnpm verify          # prettier and eslint
pnpm test            # all package tests, with test PostgreSQL and Redis
```

To run only the PDS tests, run `pnpm test` inside `packages/pds`
(`pnpm test:sqlite` skips PostgreSQL and Redis). The Makefile
wraps the same steps (`make deps`, `make build`, `make test`, `make lint`).

## Contributing

Report bugs in the fork's hook and request changes in
[GitHub issues](https://github.com/subculture-collective/pirs-atproto/issues).
Bugs in upstream AT Protocol code belong with
[bluesky-social/atproto](https://github.com/bluesky-social/atproto).

Send code as a pull request on GitHub against `main`. CI checks changesets,
then builds, verifies (prettier and eslint) and tests the packages on every
pull request. [CONTRIBUTING.md](CONTRIBUTING.md) and
[STYLE_GUIDE.md](STYLE_GUIDE.md) are upstream's and describe the code
conventions.

## License

Dual-licensed under MIT and Apache-2.0, like upstream. See
[LICENSE.txt](LICENSE.txt), [LICENSE-MIT.txt](LICENSE-MIT.txt) and
[LICENSE-APACHE.txt](LICENSE-APACHE.txt). The fork's changes are offered under
the same terms.

## Upstream README

The rest of this file is upstream's README.

Welcome friends!

This repository contains Bluesky's reference implementation of AT Protocol, and of the `app.bsky` microblogging application service backend.

### About AT Protocol

The Authenticated Transfer Protocol ("ATP" or "atproto") is a decentralized social media protocol, developed by [Bluesky Social PBC](https://bsky.social). Third-party software can be as seamless as first-party: custom feeds, federated services, and alternative clients are all built against the same APIs, so developers are never locked out of the ecosystems they help build. Learn more at:

- [Overview and Guides](https://atproto.com/guides/overview) 👈 Best starting point
- [Github Discussions](https://github.com/bluesky-social/atproto/discussions) 👈 Great place to ask questions
- [Protocol Specifications](https://atproto.com/specs/atp)

The Bluesky Social application encompasses a set of schemas and APIs built in the overall AT Protocol framework. The namespace for these "Lexicons" is `app.bsky.*`.

### What is in here?

**Lexicons:** for both the `com.atproto.*` and `app.bsky.*` are canonically versioned in this repo, for now, under `./lexicons/`. These are JSON files in the [Lexicon schema definition language](https://atproto.com/specs/lexicon), similar to JSON Schema or OpenAPI.

**TypeScript Packages:** everything under [`./packages/`](./packages/) is published to npm under the `@atproto/*` scope (except for the shared utilities in [`./packages/internal/`](./packages/internal/), which use the `@atproto-labs/*` scope). Each package has its own README; [`packages/README.md`](./packages/README.md) lists them all. The short version, if you're new here:

- **Building an app or bot?** Start with [`@atproto/lex`](./packages/lex/lex/README.md) — the type-safe SDK that generates TypeScript from Lexicon schemas and gives you an HTTP (XRPC) client. The rest of [`./packages/lex/`](./packages/lex/) contains its building blocks (data model, JSON/CBOR encoding, schema validation, server routing), which you rarely need to install directly. The older [`@atproto/api`](./packages/api/README.md) client still exists and is still used in parts of this repo, but new code should prefer `@atproto/lex`.
- **Adding "Sign in with Bluesky"?** The OAuth client and server implementations live in [`./packages/oauth/`](./packages/oauth/) — pick the client variant matching your runtime ([browser](./packages/oauth/oauth-client-browser/README.md), [node](./packages/oauth/oauth-client-node/README.md), [expo](./packages/oauth/oauth-client-expo/README.md)).
- **Implementing atproto itself?** The protocol primitives are split into focused packages: identifier parsing ([`syntax`](./packages/syntax/README.md)), DID/handle resolution ([`identity`](./packages/identity/README.md), [`did`](./packages/did/)), signing ([`crypto`](./packages/crypto/README.md)), repository & Merkle Search Tree ([`repo`](./packages/repo/README.md)), and firehose consumption ([`sync`](./packages/sync/)).
- **Everything else** is either a service implementation (see below), shared internal glue ([`common`](./packages/common/README.md), [`common-web`](./packages/common-web/README.md), [`./packages/internal/`](./packages/internal/)), or dev tooling ([`dev-env`](./packages/dev-env/), [`dev-infra`](./packages/dev-infra/)).

**TypeScript Services:** each has its implementation in `packages/<name>` and a thin runtime wrapper in `services/<name>`.

- `pds`: "Personal Data Server", hosting repo content for atproto accounts. See [bluesky-social/pds](https://github.com/bluesky-social/pds) for directions on self-hosting.
- `bsky`: AppView implementation of the `app.bsky.*` API endpoints. Running on main network at `api.bsky.app`.
- `bsync`: Internal synchronization service used by the AppView for cross-service state such as mutes and notifications.
- `ozone`: Moderation service implementing the `tools.ozone.*` API.

### What is not in here?

The source code for the Bluesky Social client app (for web and mobile) can be found at [bluesky-social/social-app](https://github.com/bluesky-social/social-app).

Go programming language source code is in [bluesky-social/indigo](https://github.com/bluesky-social/indigo), including the BGS implementation.

### Contributions

While we do accept contributions, we prioritize high quality issues and pull requests. See [CONTRIBUTING.md](./CONTRIBUTING.md) for the developer quickstart, the rules and guidelines to follow before filing an issue or submitting a PR, and our policy on LLM-assisted contributions. Code conventions are documented in [STYLE_GUIDE.md](./STYLE_GUIDE.md).

### Security disclosures

If you discover any security issues, please send an email to security@bsky.app. The email is automatically CCed to the entire team, and we'll respond promptly. See [SECURITY.md](https://github.com/bluesky-social/atproto/blob/main/SECURITY.md) for more info.

### License

This project is dual-licensed under MIT and Apache 2.0 terms:

- MIT license ([LICENSE-MIT.txt](https://github.com/bluesky-social/atproto/blob/main/LICENSE-MIT.txt) or http://opensource.org/licenses/MIT)
- Apache License, Version 2.0, ([LICENSE-APACHE.txt](https://github.com/bluesky-social/atproto/blob/main/LICENSE-APACHE.txt) or http://www.apache.org/licenses/LICENSE-2.0)

Downstream projects and end users may chose either license individually, or both together, at their discretion. The motivation for this dual-licensing is the additional software patent assurance provided by Apache 2.0.

Bluesky Social PBC has committed to a software patent non-aggression pledge. For details see [the original announcement](https://bsky.social/about/blog/10-01-2025-patent-pledge).
