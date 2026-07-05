# gen-class — the class-share mechanism (partition / contract / apply / gate)

[![CI](https://github.com/sini/gen-class/actions/workflows/ci.yml/badge.svg)](https://github.com/sini/gen-class/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/sini)

Pure-Nix, `nixpkgs.lib`-free **class-share** mechanism for the pure-gen module system. Given a set of
nodes that a partition key groups into classes, gen-class computes each class's byte-identical shared
**core** (the projection subtree every member agrees on, key-by-key), applies that core back onto a
member so it pays only its per-member delta, and **byte-gates** every reuse claim — a class-share is
authorised only by sha256 equality between the core-applied candidate and the real member, never by
the partition key.

It is the productization of the A1 fleet campaign's realization-plane arm (hola Task 7b): the oracle,
the injector, and the STOP-on-diff gate lifted from that driver and generalized to N members. Two
tiers:

- **Tier 1** (nixpkgs terminals, buildable now) — partition, the per-class byte-identical-intersection
  oracle, projection config-merge + the `extendModules` variant, the invariance probe, the byte gate.
  Every tier-1 verb runs with `merge = null`.
- **Tier 2** (pure substrate, opt-in) — `applyCoreFixed` drives [gen-merge](https://github.com/sini/gen-merge)'s
  fixed-input kernel: the engine skips the discharge/fold/verify **spine** for a core loc that is a
  pre-merged value, byte-identically. Needs the injected `merge` value.

Design spec (authoritative on all semantics): `den-architecture/gen-specs/gen-class/2026-07-05-gen-class-v1-design.md`.

## Layering

```
gen-prelude → gen-class   (Class B: prelude required; merge injected for tier 2 only)
gen-merge  ─(injected)─┘  (the tier-2 fixed-input kernel — a VALUE, never a flake input)
```

gen-class is a Class-B lib (deps injected per the gen convention): `prelude` is the sole required
dep (gen-prelude, the pure utility base); `merge` is [gen-merge](https://github.com/sini/gen-merge)'s
`lib`, injected by the consumer (the hub `mkGenLibs.class` passes it) only to enable tier 2. It borrows
[gen-resolve](https://github.com/sini/gen-resolve)'s `classKey` semantics as a **discipline** (the
`keyOf` contract below), not as a dependency.

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-prelude](https://github.com/sini/gen-prelude) | Pure nixpkgs-lib-free utility base (builtins re-exports + vendored lib utils) |
| [gen-algebra](https://github.com/sini/gen-algebra) | Pure primitives (record, search monad, either, intensional identity) |
| [gen-types](https://github.com/sini/gen-types) | Clean-room MIT structural type checker (leaf/poly checkers; `verify: v → null\|err`) |
| [gen-merge](https://github.com/sini/gen-merge) | Byte-mode module merge engine (`evalModuleTree`); hosts the tier-2 fixed-input kernel |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries (kinds, instances, collections, refs); re-hosted on gen-merge |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect type system (traits, classification, dispatch); re-hosted on gen-merge |
| [gen-scope](https://github.com/sini/gen-scope) | HOAG scope-graph evaluator (demand-driven, \_eval memoization, circular attributes) |
| [gen-graph](https://github.com/sini/gen-graph) | Accessor-based graph query combinators (traversal, condensation, phaseOrder) |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra (pattern matching over graph positions) |
| [gen-bind](https://github.com/sini/gen-bind) | Module binding (inject external args into NixOS modules) |
| [gen-dispatch](https://github.com/sini/gen-dispatch) | Relational rule dispatch STEP (stratified phases, conflict resolution) |
| [gen-resolve](https://github.com/sini/gen-resolve) | Demand-driven RAG evaluator over scope graphs (attribute schedule + convergence loop) |
| [gen-class](https://github.com/sini/gen-class) | **This lib** — class-share mechanism (partition / contract / apply / gate), byte-gated, tier-2 fixed-input via gen-merge |
| [gen-rebuild](https://github.com/sini/gen-rebuild) | Pure-Nix incremental rebuilder (change propagation, AFFECTED set) |
| [gen-vars](https://github.com/sini/gen-vars) | Pure-Nix vars/secrets (den-agnostic) |
| [gen-flake](https://github.com/sini/gen-flake) | The nixpkgs boundary — compose purely, inject resolved values, build NixOS systems (value-injection) |

## The four verb groups

| verb group | exports | role |
|---|---|---|
| **partition** | `mkClasses` | group nodes into classes by a `keyOf` key — *keys narrow, they do not authorise* |
| **contract** | `mkClass`, `mkCoreRecord` | the Class / Core plain-data records + validators (the seam as data) |
| **apply** | `mkCore`, `applyCoreMerge`, `applyCoreExtend`, `invariantUnder`, `applyCoreFixed` | the per-class oracle + core-application mechanisms |
| **gate** | `gateCore`, `compareCounters` | the hard-fail byte gate + the pure half of the two-tier counter policy |

`mkCore` is the oracle: `sharedKeys` = the keys **present in every member** whose values are
`toJSON`-equal to the archetype's (presence-guarded — a member missing an archetype key drops that key
from the core). The gate, not the key, is authority: a projection is shared only when `gateCore`'s
sha256 over canonical `toJSON` matches.

## The three planes (honest scope, with the A1 numbers)

The class-share win is **real and byte-identical but plane-shaped** — the same class-level work reads
differently from three execution planes. All figures are from the A1 fleet campaign
(`den-architecture/gen-specs/2026-07-05-a1-fleet-measurement-report.md`, hola `d643a8d`, the real
three-host fleet bitstream/blade/cortex), each a permanent byte-gated regression:

| plane | what it measures | the A1 number (with its scope) | reading |
|---|---|---|---|
| **deploy-time incremental** (cross-eval) | recompute a localized change would repeat host-by-host across separate evals | a single-host edit **skips 66.7%** of fleet composition, byte-sound (Arm R, gate floor ≥ 0.60) | large win — where [gen-rebuild](https://github.com/sini/gen-rebuild)'s incremental reuse lands; NOT a from-scratch speedup |
| **in-eval declaration** (shared-process) | is the shared option-declaration tree free to share within one eval? | blade+cortex from one `out` ≈ **1.066×** a single host, not 2× (Arm C keystone) | already free — native Nix thunk memoization shares it; nothing for a framework to add |
| **in-eval realization** (shared-process) | is host-specific realization free to share within one eval? | a **212-unit (76.3%)** byte-identical `systemd.units` core injects byte-identically; config-merge saves **~1.6%/member** (Task 7b, floor ≥ 0.008) | partially shareable, must be engineered — the den-hoag target |

Realization is small because a member's `systemd.units` *value* realization is ~2% of its eval; the
host-specific config-resolution **spine** (~98%) dominates, and config-merge (`applyCoreMerge`) cannot
share that spine across genuinely-distinct hosts. **Tier 2 is the lever for that spine:** the
synthetic homogeneous prior measured `1.89×` (the `extendModules` path, which re-runs the member's
merge) vs `2.48×` (fixed-input, where the engine treats the core as a fixed input) — the **~31%
spine-tax margin** between them is exactly what `applyCoreFixed` recovers, and it is tier 2's target on
the hub perf-bench. That margin is only reachable on OUR engine (gen-merge); a nixpkgs terminal cannot
skip the spine.

## Usage

Import with prelude only for the tier-1 surface (`merge = null`):

```nix
let
  genClass = import (fetchGit "https://github.com/sini/gen-class").outPath {
    prelude = genPrelude;             # gen-prelude.lib
  };
  inherit (genClass) mkClasses mkCore applyCoreMerge applyCoreExtend invariantUnder gateCore;
in
```

**partition** — group nodes, singletons pass through as 1-member classes:

```nix
classes = mkClasses {
  nodes  = { blade = { class = "host"; }; cortex = { class = "host"; }; lonely = { class = "solo"; }; };
  keyOf  = name: node: node.class;    # classKey discipline: MUST return a string
};
# ⇒ [ { key="host"; members=["blade" "cortex"]; archetype="blade"; … }
#      { key="solo"; members=["lonely"]; … } ]
```

**apply (config-merge)** — compute the core, then reconstruct a member paying only its delta:

```nix
core = mkCore {
  class       = hostClass;            # a mkClass / mkClasses record
  projection  = "systemd.units";      # names the projected subtree (documentation, not a path splitter here)
  projections = { blade = bladeUnits; cortex = cortexUnits; };   # memberName → projection attrs
};
cortexReconstructed = applyCoreMerge { inherit core; memberProjection = cortexUnits; };
# ⇒ core.values // (cortex's own keys minus the shared ones)  — the projection SUBTREE, not a toplevel
```

**apply (extendModules)** — the nixpkgs-terminal variant that yields a deployable toplevel by paying
the full per-member re-eval (the A1 1.89× path):

```nix
system' = applyCoreExtend { inherit core; system = nixosSystemForCortex; };
# force-wraps core.values per key under core.projection via system.extendModules
```

**apply (invariance probe)** — guard a leaf you might naively assume shared (the `system.path` lesson):

```nix
invariantUnder { projection = "system.path"; projections = hostProjections; class = hostClass; }
# ⇒ { invariant = false; divergingKeys = [ … ]; }  — a leaf that is host-specific, not shareable
```

**gate** — authorise the reuse (hard-fail on any byte divergence):

```nix
g = gateCore { inherit core; candidate = cortexReconstructed; real = cortexUnits; };
# ⇒ { gate = true; candidateDigest; realDigest; coreCount = length core.sharedKeys; }
# ci drivers hard-fail on `gate == false`; there is NO gate-free reuse path in this API (spec §2.4).

compareCounters {                     # the pure half of the two-tier STOP-on-diff policy
  expected = { nrFunctionCalls = 46261629; };
  actual   = { nrFunctionCalls = 46261621; };
  mode     = { band = 0.001; };       # "exact" (same-build) | { band } (cross-build, ±0.1% default)
};
# ⇒ { pass = true; verdicts = [ { counter; expected; actual; delta; pass; } ]; }
```

**tier 2 (`applyCoreFixed`)** — inject the injected gen-merge kernel and skip the spine:

```nix
let
  genClass = import (fetchGit "https://github.com/sini/gen-class").outPath {
    prelude = genPrelude;
    merge   = genMerge;               # gen-merge.lib — REQUIRED for tier 2 (else applyCoreFixed throws)
  };
in
(genClass.applyCoreFixed {
  inherit core;
  modules = [ memberAxisModule ];     # members contribute AXIS locs; coreModule carries the core-projection def
}).config
# builds merge.evalModuleTree { coreShortCircuit = true; modules = modules ++ [ coreModule ]; }
# where the short-circuit returns core.values directly for the sole-def core loc — byte-identical to the
# full merge (a WRONG core surfaces at gateCore, not here).
```

## The tier-2 firing contract

`applyCoreFixed` places the core at a `coreModule` whose projection option leaf carries a single
`mkCoreValue`-tagged def. The gen-merge kernel short-circuits **only where that core def is the SOLE
def at a declared-option leaf**. gen-class upholds that firing condition by construction:

- **whole-leaf placement** — the marker sits at the whole projection option leaf, never at sub-keys of
  an `attrsOf` (those ride the plain per-element fold and never short-circuit);
- **no `default`** — the coreModule declares the option with no `default` (a default appends a second,
  lowest-priority def, demoting a sole-core to fall-through — still byte-identical, but no spine skip);
- **type-less coreModule** (`merge.mkOption { }`) — the core projection loc is coreModule's to *define*;
  coreModule carries **no `.type`** to clobber a member's declaration. **A member module supplying the
  core loc SHOULD declare the option's real type** — coreModule's type-less declaration loses the option
  field-union to the member's typed one (later-wins on `.type`), so the option ends up with the member's
  intended merge-type while the marker stays the sole def and the skip still fires.

**Fall-through is SAFE, and "safe" is the strong claim.** A member module that also *defines* (not just
declares) the core loc forfeits the spine skip: the kernel falls through to the **full merge**, and its
output is **byte-identical to the full merge INCLUDING the full merge's own merge and error semantics**.
"Safe" here means *no divergence from the full merge* — it does **not** mean "cannot conflict." A
type-less member redefinition that genuinely conflicts with the core throws **exactly as the full merge
would have thrown**; fall-through neither adds nor suppresses a conflict. The kernel is defaulted off
(`coreShortCircuit ? false`), so a consumer never enabling it sees zero behavior change. Both the
skip case and the fall-through case are byte-gated in `ci/tests/apply-fixed.nix`.

## Scope fences

- **Intra-process only.** Every plane here is *within one eval*. Cross-invocation / cross-eval caching
  (Plane 2b) is out of scope — the deploy-time 66.7% number lives in [gen-rebuild](https://github.com/sini/gen-rebuild),
  not here.
- **Projection-only for the merge path.** `applyCoreMerge` / `applyCoreFixed` return the projection
  **subtree**, not a deployable toplevel. Recovering a full toplevel *from* the spine-skipped path is
  **tier 3 (den-hoag)** — a distinct, engine + den-hoag-level capability. `applyCoreExtend` is the only
  verb that yields a deployable toplevel, and it does so legitimately by paying the full per-member
  re-eval (it does not skip the spine).
- **Tier 3 = den-hoag.** Boundary declaration from den's aspect structure (declare-don't-discover),
  instantiate wiring, and full-toplevel recovery are den-hoag's to build — den-hoag *consumes*
  gen-class as wiring. The seam contract (cores applied inside r2's terminal assembly,
  `output-modules → lib.nixosSystem`) ships as a PROPOSAL in the r2-amendment note (papers).
- **Byte-mode only.** The gate is byte equality (canonical `toJSON`). Confluent/structural merge,
  structural equivalence (`≈ₛ`), and Merkle-id gate-free reuse are a separate, deferred mode.

## Compat / purity

- **Class-B value injection.** `prelude` and `merge` enter as injected VALUES, exactly as gen-merge
  takes `types` — the same value-injection philosophy as [gen-flake](https://github.com/sini/gen-flake).
  `merge` is optional (defaults `null`): the whole tier-1 surface works without it, and `applyCoreFixed`
  throws a clear gen-class error naming the missing injection.
- **Purity fence.** `lib/` is `nixpkgs.lib`-free — the forced-override record `applyCoreExtend` hands
  `extendModules` is hand-built (`{ _type = "override"; priority = 50; }`, byte-compatible with nixpkgs
  `mkForce`), so the library carries no nixpkgs dependency. Enforced by `ci/tests/purity.nix` (a
  recursive token scanner over `lib/` + `flake.nix` + `default.nix`). nixpkgs enters ONLY in `ci/` (the
  nix-unit harness + the `applyCoreExtend` equivalence fixture's `evalModules` reference side).
- **Naming fence.** The public surface never uses the verb `inject` — den-hoag r2 binds that name to a
  resolution effect (`policy.provide`, r2:201). Verbs are `mkClasses` / `mkCore` / `applyCore*` /
  `gateCore`, and the API stays FLAT. Enforced by `ci/tests/fence.nix` (walks the public attrset + the
  `lib/` file names; a poisoned-attrset fixture proves the fence has teeth).

## Testing

`nix flake check ./ci` runs the nix-unit suites (self-contained — a synthetic corpus, no
nix-config/den inputs): `contract` (record constructors + every validation throw), `partition`
(grouping / determinism / singletons + the corpus self-checks), `apply` (oracle correctness incl a
deliberately-divergent member, `applyCoreMerge` reconstruction identity, `applyCoreExtend` equivalence
on an `evalModules` fixture, the invariance probe), `gate` (byte-gate teeth: a corrupted core must
fail), `apply-fixed` (tier-2 skip + fall-through, both byte-gated + a deterministic firing proof),
`purity`, and `fence`. The synthetic corpus is one homogeneous 6-member class (40-key shared core) and
one heterogeneous blade/cortex pair (19 shared / 4 divergent / 2 blade-only keys — 76% shared,
mirroring the A1 7b pair), including a designed `system.path`-style non-invariant leaf.

## Theoretical foundations

- **Reynolds defunctionalization (keys before closures).** Parametric class behavior is reduced to
  plain-data records (`Class` / `Core`) BEFORE anything is keyed, so partition / apply / gate operate on
  first-order values — the m5 discipline the whole gen corpus shares.
- **Gate-B / WHNF spine bound.** A class-share is authorised only by byte equality between the
  core-applied candidate and the real member (the gate decides, the key narrows); the residual the gate
  cannot remove is the WHNF config-resolution spine (~98% of a member), which is precisely what tier 2
  and later den-hoag target.
- **A1 / 7b empirical grounding.** The oracle, injector, and STOP-on-diff gate are lifted from hola
  Task 7b (`ci/bench/class-share-realization.sh`), and every plane number is a permanent byte-gated
  regression pinned to a committed baseline (`hola/ci/bench/baselines/`, `d643a8d`).
