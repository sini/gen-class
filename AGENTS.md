# gen-class — agent capability sheet

## Scope

Class-share mechanism: groups nodes into classes by a caller-supplied key (`mkClasses`), computes each class's byte-identical shared **core** over a named projection (`mkCore`), applies that core back onto a member (`applyCoreMerge` / `applyCoreExtend` / tier-2 `applyCoreFixed`), and authorises every reuse claim by sha256 over canonical `toJSON` (`gateCore`).

## Not this library's job

Quoted text is the owner's own `flake.nix` `description` field, verbatim.

| Responsibility | Owner |
|---|---|
| Evaluating the module tree, merge semantics, the fixed-input kernel (`evalModuleTree`, `mkOption`, `mkCoreValue`, `mkOptionType`) | `gen-merge` — "gen-merge — pure-Nix byte-mode module MERGE engine (evalModuleTree) for the pure-gen module system". Injected as a VALUE, never a flake input: `git grep -n "\.url = " -- flake.nix` returns `flake.nix:11` (`gen-prelude`) and nothing else |
| General utilities (`attrNames`, `sort`, `filter`, `listToAttrs`, `unique`, …) | `gen-prelude` — "gen-prelude: vendored, nixpkgs-lib-free pure utilities for the gen ecosystem". The sole flake input |
| Computing the partition key itself (classKey semantics — sorted include-sets / sanitised resolved-aspects) | `gen-resolve` — "gen-resolve — demand-driven higher-order RAG evaluator over algebraic scope graphs (Knuth 1968 attribute schedule + Vogt 1989 HOAG)". Borrowed as a *discipline* only (`lib/partition.nix:3-12`); `git grep -n "gen-resolve" -- lib/` ⇒ no match (control, same command shape: `git grep -n -c "gen-merge" -- lib/` ⇒ `lib/apply.nix:5`, `lib/default.nix:1`) |
| Deciding WHICH nodes form a class (boundary declaration) | the caller — `mkClasses` takes `keyOf` and never discovers a boundary. README "Scope fences" assigns declare-don't-discover boundaries and full-toplevel recovery to den-hoag as tier 3 |
| Cross-eval / cross-invocation incremental reuse (the deploy-time plane) | `gen-rebuild` — "gen-rebuild: pure-Nix incremental rebuilder core (Mokhov rebuilder dimension)". README "Scope fences" states gen-class is intra-process only |
| Building NixOS systems, the nixpkgs boundary, value injection | `gen-flake` — "gen-flake — the pure composition boundary of the pure-gen module ecosystem" |
| Type checking / `verify` | `gen-types` — "gen-types: pure, nixpkgs-lib-free structural type checker for the gen ecosystem" |
| Minting identity, kinds, instances, registries (gen-class hashes only its own core `values`, and mints no id) | `gen-schema` — "gen-schema: typed record registry with extension points for the pure-gen module system" |
| Aspect traits / classification a caller might build a `keyOf` from | `gen-aspects` — "gen-aspects: aspect-oriented composition types (pure-gen, re-hosted on gen-merge)" |
| Selecting which nodes match a predicate | `gen-select` — "gen-select: selector algebra for attributed graph positions" |
| Traversal / queries over the resulting class structure | `gen-graph` — "gen-graph: accessor-based graph query combinators" |
| Choosing a winner among competing rules | `gen-dispatch` — "gen-dispatch: relational rule dispatch over ordered groups (the dispatch STEP)" |

## Exports

Two real wirings, both `import ./lib`:

- **flake `.lib`** — `import ./lib { prelude = gen-prelude.lib; }` (`flake.nix:15-17`). `merge` defaults to `null` (`lib/default.nix:6`), so this is the **tier-1** surface.
- **hub `mkGenLibs.class`** — `import "${genInputs.gen-class}/lib" { prelude = …; merge = genInputs.gen-merge.lib; }` (`gen/lib/mkGenLibs.nix:38-41`), the **tier-2** surface. gen-class is the one Class B member the hub re-imports rather than re-exporting.

The export **names are identical under both wirings** (drift check below): `applyCoreFixed` is unconditionally exported and throws only when called with `merge = null`. Root `default.nix` is the non-flake twin (same two arguments, gen-prelude defaulted from `flake.lock`).

The surface is FLAT — `contract // partition // apply // gate` (`lib/default.nix:14`), 10 names, no shadowing.

**partition** — `lib/partition.nix`

| Export | Signature |
|---|---|
| `mkClasses` | `{ nodes : attrs; keyOf : name -> node -> str } -> [Class]` (key-sorted, members sorted) |

**contract** — `lib/contract.nix`

| Export | Signature |
|---|---|
| `mkClass` | `{ key : str; members : [str]; archetype ? null } -> Class` |
| `mkCoreRecord` | `{ class : Class; projection : str; sharedKeys : [str]; values : attrs } -> Core` |

**apply** — `lib/apply.nix`

| Export | Signature |
|---|---|
| `mkCore` | `{ class : Class; projection : str; projections : memberName -> attrs } -> Core` (the oracle) |
| `applyCoreMerge` | `{ core : Core; memberProjection : attrs } -> attrs` (projection subtree) |
| `applyCoreExtend` | `{ core : Core; system } -> system.extendModules result` |
| `invariantUnder` | `{ projection : str; projections; class : Class } -> { invariant : bool; divergingKeys : [str] }` |
| `applyCoreFixed` | `{ core : Core; modules : [module]; engineArgs ? {} } -> { config; options; type; }` (tier 2, needs `merge`) |

**gate** — `lib/gate.nix`

| Export | Signature |
|---|---|
| `gateCore` | `{ core : Core; candidate; real } -> { gate : bool; candidateDigest : str; realDigest : str; coreCount : int }` |
| `compareCounters` | `{ expected : attrs; actual : attrs; mode : "exact" \| { band : float } } -> { pass : bool; verdicts : [{ counter; expected; actual; delta; pass; }] }` |

**Records** (constructed, not separately exported). `Class = { _type = "gen-class/class"; key; members; archetype; }`; `Core = { _type = "gen-class/core"; class; projection; sharedKeys; values; digest; }` where `digest = hashString "sha256" (toJSON values)` (`lib/contract.nix:105`). `Axis` is named in the contract comment as a consumer-shaped per-member delta record with **no constructor** (`lib/contract.nix:20-22`).

## Entry points by task

| Task | Reach for |
|---|---|
| Group nodes into classes | `mkClasses { nodes; keyOf; }` — `keyOf` must return a string |
| Build a class by hand (fixtures, explicit archetype) | `mkClass` |
| Compute what a class actually shares | `mkCore` — presence-guarded byte-identical intersection over the archetype's keys |
| Reconstruct a member from a core (subtree only) | `applyCoreMerge` |
| Reconstruct a member as a deployable nixpkgs toplevel | `applyCoreExtend` — pays the full per-member re-eval |
| Reconstruct a member skipping the gen-merge spine | `applyCoreFixed` — tier 2, requires the injected `merge` |
| Ask whether a leaf is shareable before committing to it | `invariantUnder` — returns `divergingKeys` |
| Authorise a reuse claim | `gateCore`; hard-fail on `gate == false` (no gate-free path exists in this API) |
| Gate an eval-counter regression | `compareCounters` — `"exact"` same-build, `{ band = 0.001; }` cross-build |
| Build a Core from keys you already trust | `mkCoreRecord` — validates sorted/unique `sharedKeys` and `attrNames values == sharedKeys` |

## Measured traps

Verified at `e021123` on Nix 2.34.8. Shared fixtures: `gc = import ./lib { inherit prelude; }` (merge = null); `gcm` = the same with `merge` injected; `t = x: (builtins.tryEval (builtins.deepSeq x x)).success`; `cls = gc.mkClass { key = "h"; members = [ "blade" "cortex" ]; }` (archetype ⇒ `"blade"`); `projs = { blade = { shared = 1; div = "b"; bladeOnly = 9; }; cortex = { shared = 1; div = "c"; }; }`; `core = gc.mkCore { class = cls; projection = "systemd.units"; projections = projs; }`.

| Trap | Evidence |
|---|---|
| `applyCoreFixed` is *present* on the merge-null surface — presence is not availability; it throws on CALL | drift output lists it under `flakeLib`; `t (gc.applyCoreFixed { core; modules = []; })` ⇒ `false`, message from `lib/apply.nix:167`: `` gen-class: applyCoreFixed: the tier-2 fixed-input path requires the injected gen-merge kernel, but `merge` is null. `` Positive control, same call on `gcm` ⇒ built, `.config.systemd.units == core.values`. Test: `test-merge-null-throws` (`ci/tests/apply-fixed.nix`) |
| The oracle scans the **archetype's** keys only — a key every non-archetype member carries and agrees on is invisible | `lib/apply.nix:82`; `projections = { blade = { a = 1; }; cortex = { a = 1; z = 7; }; }` ⇒ `sharedKeys = ["a"]`, no `z` |
| Presence guard drops an archetype key a member lacks (not a throw, not a share) | `lib/apply.nix:81`; `core.sharedKeys` ⇒ `["shared"]` — `bladeOnly` gone, `div` gone. Tests: `test-hetero-presence-guard` (`ci/tests/partition.nix`), `test-hetero-oracle-excludes-divergent-and-blade-only` (`ci/tests/apply.nix`) |
| `mkClass` stores `members` **as given** but the default archetype is the byte-order-first member — `archetype != head members` | `lib/contract.nix:74`; `members = [ "zeta" "alpha" "mid" ]` ⇒ stored unchanged, `archetype` ⇒ `"alpha"`. Test: `test-default-archetype-lexicographic` (`ci/tests/contract.nix`) |
| Ordering is `builtins.lessThan` byte order, so an uppercase member takes the archetype | `lib/partition.nix:51`, `lib/contract.nix:74`; `nodes = { alpha; Zulu; beta; }` under one key ⇒ `members = [ "Zulu" "alpha" "beta" ]`, `archetype = "Zulu"` |
| `mkClasses` returns a **list**, and empty `nodes` returns `[]` rather than throwing | `lib/partition.nix:47-53`; `isList` ⇒ `true`; `mkClasses { nodes = {}; keyOf = _: _: "k"; }` ⇒ `[]` |
| Three failure modes escape `tryEval` entirely (they are evaluator errors, not gen-class throws) | (a) `keyOf` returning a non-string ⇒ `error: expected a string but found an integer: 1` (`lib/partition.nix:45`, `builtins.groupBy`); (b) a member absent from `projections` ⇒ `error: attribute 'cortex' missing` (`lib/apply.nix:81`); (c) a function-valued projection key ⇒ `error: cannot convert a function to JSON` (`lib/apply.nix:81`). Positive controls, same harness same run: `t (gc.mkClass { key = 1; members = ["a"]; })` ⇒ `false` (a gen-class `throw`, caught), and case (c) with `f = 1` instead of `f = x: x` ⇒ `success = true` |
| An empty intersection is a **valid** Core, and `applyCoreMerge` over it is identity | `lib/apply.nix:78-90`; `projections = { blade = { a = 1; }; cortex = { a = 2; }; }` ⇒ `sharedKeys = []`, `_type = "gen-class/core"`; `applyCoreMerge` with `memberProjection = { a = 2; extra = 5; }` ⇒ `{ a = 2; extra = 5; }`. Tests: `test-empty-core-sharedKeys`, `test-empty-core-merge-is-identity` (`ci/tests/apply.nix`) |
| `applyCoreMerge` — the **core wins** at a shared key; a member's own value there is discarded | `lib/apply.nix:101`; `memberProjection = { shared = 999; div = "c"; }` ⇒ `{ div = "c"; shared = 1; }`. Test: `test-core-owns-shared-keys` (`ci/tests/apply.nix`) |
| `gateCore` reads `core` only for the type guard and `coreCount` — it never checks the candidate came from *that* core | `lib/gate.nix:49-66`; an alien core (`projection = "other"`, `values = { q = 42; }`) with `candidate = real = { z = 1; }` ⇒ `{ gate = true; coreCount = 1; }` |
| `gateCore` never throws on the **outcome** (a `false` gate is a record) but does throw on a non-`gen-class/core` first argument | `lib/gate.nix:56`; mismatch ⇒ `{ gate = false; candidateDigest ≠ realDigest; }`, `isAttrs` ⇒ `true`; `t (gc.gateCore { core = { a = 1; }; candidate = 1; real = 1; })` ⇒ `false`. Test: `test-gate-teeth-corrupt-fails` (`ci/tests/gate.nix`) |
| The digest is key-order-insensitive, and `core.digest` is the same function `gateCore` applies | `lib/contract.nix:105`, `lib/gate.nix:43`; `candidate = { a = 1; b = 2; }` vs `real = { b = 2; a = 1; }` ⇒ `gate = true`; `core.digest` ⇒ `a8b49b44…` equals `gateCore` on `core.values`; the empty core's digest ⇒ `44136fa3…` = `hashString "sha256" (toJSON {})`. Test: `test-digest-key-order-invariant` (`ci/tests/contract.nix`) |
| `compareCounters` **throws** on a counter-set mismatch or a bad `mode` — it does not report `pass = false` | `lib/gate.nix:111-114`; `expected = { n = 1; }` / `actual = { m = 1; }` ⇒ `t` `false`; `mode = "band"` (the string) ⇒ `t` `false` |
| The band is inclusive, and a zero baseline never passes a sub-unit band | `lib/gate.nix:72-79,107`; `expected = { n = 1000; }`, `actual = { n = 1001; }`, `band = 0.001` ⇒ `pass = true`; `expected = { n = 0; }`, `actual = { n = 1; }`, `band = 0.5` ⇒ `delta = 1.0`, `pass = false` |
| `verdicts` come back in `attrNames expected` (sorted) order, not caller order | `lib/gate.nix:109`; `{ z; a; m; }` ⇒ `[ "a" "m" "z" ]` |
| `invariantUnder` **requires** `projection` and then ignores it | `lib/apply.nix:120-141`; `projection = "systemd.units"` and `projection = "TOTALLY-DIFFERENT"` both ⇒ `{ invariant = false; divergingKeys = [ "bladeOnly" "div" ]; }` (the archetype-only key counts as diverging); omitting it ⇒ `error: function 'invariantUnder' called without required argument 'projection'`, which also escapes `tryEval` |
| `core.projection` is inert in `mkCore` / `applyCoreMerge` but a dotted **path** in `applyCoreExtend` / `applyCoreFixed` | `lib/apply.nix:56-64,112,170`; `applyCoreFixed` with `"systemd.units"` ⇒ `r.config.systemd.units == core.values`; with `"nodots"` ⇒ `r.config.nodots` |
| `projection` is validated only as a string — `""` is accepted and builds a `""`-named option | `lib/contract.nix:86-87`; `mkCore { projection = ""; … }` succeeds, and `applyCoreExtend` yields `{ modules = [ { config = { "" = { u1 = { _type = "override"; priority = 50; content = "a"; }; }; }; } ]; }` |
| `applyCoreExtend` needs no nixpkgs — it calls `system.extendModules` on whatever it is handed, and force-wraps **per key** | `lib/apply.nix:48-52,108-114`; `system = { extendModules = a: a; }` ⇒ the module above, one `{ _type = "override"; priority = 50; }` record per core key under the dotted path. Tests: `test-extend-force-wins-and-preserves-axis`, `test-extend-dotted-projection` (`ci/tests/apply.nix`) |
| `applyCoreFixed` returns the whole engine result, not the projection subtree — reach `.config` | `lib/apply.nix:176-182`; `attrNames` of the result ⇒ `[ "config" "options" "type" ]`, with a member axis key alongside: `r.config.axisKey` ⇒ `"m"` |
| `mkCoreRecord` is strict on all four fields | `lib/contract.nix:84-95`; unsorted `sharedKeys`, duplicate `sharedKeys`, a `values` carrying an extra key, and a non-`gen-class/class` `class` each ⇒ `t` `false`; the well-formed control ⇒ `true`. Tests: `test-throws-unsorted-sharedKeys`, `test-throws-duplicate-sharedKeys`, `test-throws-keys-mismatch`, `test-throws-non-class` (`ci/tests/contract.nix`) |
| The public attrset is a flat union — later group wins on a name collision | `lib/default.nix:14`; `length (attrNames gc)` ⇒ `10` = contract 2 + partition 1 + apply 5 + gate 2, so nothing is currently shadowed |

Read, not exercised: the gen-merge kernel's own firing scope (`coreShortCircuit` at a sole-def declared-option leaf) is read from `lib/apply.nix:143-159` and exercised only through the repo's own `ci/tests/apply-fixed.nix` (`test-skip-fires-through-boom`, `test-off-runs-throwing-spine`), not by a probe in this run.

## Theory

`README.md:249-260` lists "Theoretical foundations" as three flat bullets — no Implements / Informed-by split — restated in the file headers.

**Claims**

- **Reynolds defunctionalization (the m5 discipline)** — parametric class behaviour is reduced to plain-data `Class` / `Core` records *before* anything is keyed, so partition / apply / gate operate on first-order values (`lib/contract.nix:3-5`).
- **Gate-B / WHNF spine bound** — a class-share is authorised only by byte equality between the core-applied candidate and the real member; the residual the gate cannot remove is the WHNF config-resolution spine (`lib/gate.nix:3-10`).

**Empirical grounding** (measurements, not results claimed by this lib): the oracle, injector and STOP-on-diff gate are lifted from the A1 fleet campaign's Task 7b driver (hola `ci/bench/class-share-realization.sh`), with the plane figures pinned in `den-architecture/gen-specs/2026-07-05-a1-fleet-measurement-report.md` (`README.md:73-93`). The two-tier counter policy (exact same-build, relative band cross-build) is documented by reference to hola `ci/bench/MEASUREMENT.md` §"Counter determinism" (`lib/gate.nix:14-22`); thresholds are caller-supplied.

**Checked invariants**: `lib/` is nixpkgs-lib-free — a token scan over `lib/**.nix` + root `flake.nix` + `default.nix` (`ci/tests/purity.nix`, `test-library-source-is-nixpkgs-free`); `git grep -n "lib\.\(mkOption\|mkForce\|types\|evalModules\|mkMerge\)" -- lib/` ⇒ no match (control, same command shape: `git grep -c "prelude" -- lib/` ⇒ all five files). The public surface never uses the verb `inject`, with a poisoned-attrset fixture proving the check has teeth (`ci/tests/fence.nix`, `test-public-surface-has-no-inject`, `test-fence-catches-poison`).

## Drift check

The two real wirings in one command, from the repo root. `--impure` is required: pure-eval mode refuses the repo-relative reads.

```sh
nix eval --json --impure --expr 'let
  ciLock = builtins.fromJSON (builtins.readFile ./ci/flake.lock);
  fetchCi = n: builtins.fetchTree ciLock.nodes.${ciLock.nodes.root.inputs.${n}}.locked;
  prelude = import "${fetchCi "gen-prelude"}/lib";
  names = a: builtins.attrNames (import ./lib a);
in {
  flakeLib = names { inherit prelude; };
  hubLib = names { inherit prelude; merge = import (fetchCi "gen-merge") { }; };
}'
```

`flakeLib` is the flake `.lib` surface (`merge = null`); `hubLib` is the hub `mkGenLibs.class` surface (gen-merge injected). The Exports section claims **both**, and they carry the same names.

Current output (verbatim):

```json
{"flakeLib":["applyCoreExtend","applyCoreFixed","applyCoreMerge","compareCounters","gateCore","invariantUnder","mkClass","mkClasses","mkCore","mkCoreRecord"],"hubLib":["applyCoreExtend","applyCoreFixed","applyCoreMerge","compareCounters","gateCore","invariantUnder","mkClass","mkClasses","mkCore","mkCoreRecord"]}
```

**Checks.** Test-runner invocation (from the repo root; CI runs the same command with `working-directory: ci`, `.github/workflows/ci.yml:13,18`):

```sh
nix flake check ./ci
```
