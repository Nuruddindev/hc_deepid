# hc_deepid

A reusable Holochain identity zome, extracted from [NFB Den](https://nfb.digital)'s `account` zome, for applications that need **multi-device identity anchored to an external identity authority** (e.g. a Django/OAuth backend) rather than raw agent keys.

> **Status:** early extraction / work in progress. The core `account` zome (user, profile, avatar) is functional and compiles cleanly against Holochain 0.6.x. Not yet published as a standalone crate.

## The problem

In a standard Holochain hApp, each device/browser a person uses gets its own `AgentPubKey`. If your data model links content directly to `AgentPubKey`, the same person logging in from two devices looks like two different identities — profile updates, avatars, and permissions don't follow them across devices.

`hc_deepid` solves this by treating an **external identity ID** (in NFB Den's case, a Django user ID) as the source of truth, and anchoring shared state to it via `ExternalHash`, while still respecting Holochain's per-agent source-chain model underneath.

## Why this matters for contracts: Key vs. ID

The multi-device bug above is annoying for a profile picture. It's disqualifying for a legal contract.

NFB Den's `pub_contract` zome records publishing contracts between authors and publishers — but the underlying problem isn't specific to publishing. Any Holochain hApp that models a legally binding agreement — a real estate purchase or lease, a vehicle sale, an employment contract, anything where "who agreed to this" has to hold up outside the DHT — needs identity to mean *the same accountable party*, consistently, regardless of which device or browser they happened to sign in from. `pub_contract` is simply the instance of this problem NFB Den had to solve first; `hc_deepid` is the general-purpose answer.

If contract state is validated or resolved against `AgentPubKey`/device identity instead of a stable identity anchor, you get real risks in any of these domains:

- **Signing ambiguity.** If "who signed this" resolves to a device key rather than a durable identity, a party switching devices mid-negotiation can look like a different signer, or worse, make it unclear which device's key is authoritative for a signature.
- **Repudiation surface.** An agent key can be lost, rotated, or run on a compromised device. Without a stable identity layer above it, there's no clean way to say "this contract belongs to this person" independent of "this specific keypair happened to sign it."
- **No continuity across key rotation.** Holochain's own key-management layer, [DeepKey](https://github.com/holochain/deepkey), solves a different problem: it tracks whether a given `AgentPubKey` is currently valid, revoked, or replaced. That's necessary but not sufficient — DeepKey answers *"is this key still good?"*, not *"which real-world accountable party has ever stood behind any of these keys?"* A contract needs the second answer.

This is the distinction between **Key** and **ID**: DeepKey (and DPKI generally) is key-management infrastructure — it's about keys. `hc_deepid` is identity infrastructure — it's about the durable, external-authority-backed identity that a whole set of rotating, multiplying device keys can be traced back to. The two are complementary, not competing: a contract system — for publishing, real estate, vehicle sales, or any other domain — can use DeepKey to validate that a signing key is currently authorized, *and* use `hc_deepid` to resolve that key back to the accountable identity that must actually be bound by the contract.

To be precise about what's changing: `hc_deepid` doesn't turn Holochain into something other than agent-based. The source chain, validation, and DHT all remain agent-based at the protocol level, exactly as designed. What `hc_deepid` adds is a **user-centric identity layer at the application level**, sitting on top of that agent-based foundation — the same space Holochain's own DPKI work has long flagged as needing a pluggable, delegatable identity layer, but hasn't yet filled with a reusable, production-tested implementation.

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