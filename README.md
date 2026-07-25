# hc_deepid
# hc_deepid

A reusable Holochain identity zome, extracted from [NFB Den](https://nfb.digital)'s `account` zome, for applications that need **multi-device identity anchored to an external identity authority** (e.g. a Django/OAuth backend) rather than raw agent keys.

> **Status:** early extraction / work in progress. The core `account` zome (user, profile, avatar) is functional and compiles cleanly against Holochain 0.6.x. Not yet published as a standalone crate.

## The problem

In a standard Holochain hApp, each device/browser a person uses gets its own `AgentPubKey`. If your data model links content directly to `AgentPubKey`, the same person logging in from two devices looks like two different identities — profile updates, avatars, and permissions don't follow them across devices.

`hc_deepid` solves this by treating an **external identity ID** (in NFB Den's case, a Django user ID) as the source of truth, and anchoring shared state to it via `ExternalHash`, while still respecting Holochain's per-agent source-chain model underneath.

## Core pattern

```
Django/OAuth identity (django_id)
        │
        ▼
ExternalHash(django_id)  ──┬──> ActiveAvatar link  (shared, current avatar for this identity)
        │                  ├──> UserById link       (shared, resolves to the User entry)
        │                  └──> ...
        │
 AgentPubKey (device A) ───┤
 AgentPubKey (device B) ───┤   each device's local source chain still owns
 AgentPubKey (device N) ───┘   its own User/Profile/Avatar entries + AgentToUser link
```

- One `django_id` → many `AgentPubKey`s (one per device/agent).
- Shared, identity-level state (which avatar is "active", how to resolve the current profile) is anchored on `ExternalHash(django_id)`, not on any single agent.
- Per-device state (ownership, local history) still lives on each agent's own links (`AgentToUser`, `UserUpdates`, etc.), so DHT validation and source-chain integrity are untouched.

This replaces an earlier per-agent link design (`AgentToAvatar` / `AgentToProfile`) that caused a real bug in NFB Den: which avatar/profile displayed depended on which device happened to be queried, since each device only knew about its own links. `AgentToAvatar` is kept in the integrity zome for backward compatibility but is no longer used for active resolution.

## Proven in NFB Den

This isn't a theoretical design — it's the pattern currently running in [NFB Den](https://nfb.digital)'s `account` zome, validated through local development and multi-agent Tryorama testing (persistent multi-agent test environments simulating multiple devices per identity). The multi-device bug described above was real, reproduced, and fixed using exactly this `ExternalHash`-anchored approach.

*A demo video walking through the multi-device flow will be added here.*

## What's in the account zome

- **Entry types:** `User`, `Profile`, `Avatar`
- **Link types:** update-chain links per entry type (`UserUpdates`, `ProfileUpdates`, `AvatarUpdates`), ownership links (`AgentToUser`, `AgentToProfile`, `AgentToAvatar`), identity-anchored resolution links (`UserById`, `ActiveAvatar`), and discovery links (`AllUsers`, `ProfileLink`)
- **First-sync flow:** an ephemeral Django token is used once, at first sync, to pull profile data into the DHT — it is not stored. Subsequent logins on the same device are offline-capable via a local vault (`email`, `shadow_hash`, `id_nfbden`) stored outside the DHT.
- Standard `init`, `post_commit`, and signal-emission scaffolding (extended from the Holochain scaffolding tool's generated pattern).

## Requirements

- Rust (edition 2021)
- [Holochain](https://developer.holochain.org/) `0.6.x` (`hdi = "0.7.1"`, `hdk = "0.6.1"`)
- `cargo`, and the `wasm32-unknown-unknown` target for building zomes

## Building

```bash
cargo check
cargo build --release --target wasm32-unknown-unknown
```

## Repository layout

```
hc_deepid/
├── Cargo.toml                        # workspace root
├── zomes/
│   ├── integrity/account/            # entry & link type definitions, validation
│   └── coordinator/account/          # zome calls, signals
```

## Using this zome in your own hApp

`hc_deepid` isn't (yet) a scaffolding template you invoke with `hc scaffold --template`. For now, it's meant to be pulled into an existing hApp workspace as a path dependency — the same way `account`/`account_integrity` are wired together internally.

**1. Add it to your project, e.g. as a git submodule** (keeps it updatable):

```bash
git submodule add https://github.com/<you>/hc_deepid vendor/hc_deepid
```

Or just clone/copy it in if you don't need to track upstream changes.

**2. Point your workspace `Cargo.toml` at it:**

```toml
[workspace.dependencies.account]
path = "vendor/hc_deepid/zomes/coordinator/account"

[workspace.dependencies.account_integrity]
path = "vendor/hc_deepid/zomes/integrity/account"
```

**3. Register the zomes in your DNA manifest** as you would any coordinator/integrity zome pair — `hc scaffold dna` and the rest of the normal Holochain scaffolding workflow are unaffected; `hc_deepid` just becomes one of the zomes your DNA includes.

A proper `hc scaffold --template` integration (so `hc_deepid` can be scaffolded directly, not just path-linked) is on the roadmap below, once the zome API has settled.

## SDK ecosystem

`hc_deepid` defines the identity pattern on the Holochain side (the `ExternalHash`-anchored, multi-device model above), but a real application also needs a matching adapter on the identity-authority side — the thing that issues the first-sync token and owns the canonical `external_id`.

- **[`holodjango_deepid`](#)** *(in progress)* — the first such adapter, for Django. Handles issuing ephemeral first-sync tokens and exposing the `django_id` that `hc_deepid` anchors to.
- **Planned:** equivalent adapters for other stacks — an npm/JavaScript package (for Node/JS backends, or identity providers like Auth0/Firebase), a PHP package (Laravel and similar), and others as demand emerges.

The goal is for `hc_deepid` itself to stay backend-agnostic — any identity authority that can issue a short-lived first-sync token and a stable external ID should be able to pair with it via a thin SDK, without changing the zome.

## Roadmap

This repo currently contains only the `account` zome. It is being extracted and generalized from NFB Den, a decentralized publishing-contract platform, as a standalone identity building block other Holochain hApps can depend on. Feedback on the API shape is welcome before a first crates.io release.

- [ ] Publish `hc_deepid` as a standalone crate
- [ ] Finish and publish `holodjango_deepid`
- [ ] JavaScript/npm SDK
- [ ] PHP SDK
- [ ] `hc scaffold --template` integration for direct scaffolding

## License

MIT — see [LICENSE](./LICENSE).