{
  description = "gen-class — pure-Nix class-share mechanism (partition / contract / apply / gate) for the pure-gen module system";

  # Class layering: gen-prelude → gen-class (Class B, deps injected per gen convention §8). `merge`
  # is an ORDINARY root formal (owner-ruled arm A, 2026-09-15: `den-hoag-4dfsv`), resolved the same
  # three-channel way as `prelude`, and this root declares BOTH flake inputs (owner-ruled arm A,
  # 2026-09-16: `den-hoag-4dfsv` §4.2 — the pin source is the root `flake.lock`, not `ci/flake.lock`).
  # The flake output applies `./.` with BOTH declared inputs, exactly as it applies `prelude`: the
  # flake path takes each dependency from the flake's own input graph, so a consumer's `follows` or
  # `--override-input gen-merge` reaches this instance, and no second gen-merge is resolved from this
  # root's `flake.lock` behind the consumer's lock. Standalone, both inputs are this root's own lock
  # nodes — the same nodes `./.`'s defaults resolve — so the flake path and the shim path publish ONE
  # value. `.lib` is the TIER-2 surface (`applyCoreFixed` live); a tier-1-only consumer imports the
  # root directly (`import gen-class-src { merge = null; }`), which `AGENTS.md` documents.
  # The library (./lib) is nixpkgs-lib-free (ci/tests/purity.nix) and its public surface never uses
  # the verb `inject` (ci/tests/fence.nix) — den-hoag r2 binds that name to a resolution effect
  # (policy.provide, r2:201).
  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";
    gen-merge.url = "github:sini/gen-merge";
  };

  outputs =
    { gen-prelude, gen-merge, ... }:
    {
      lib = import ./. {
        prelude = gen-prelude.lib;
        merge = gen-merge.lib;
      };
    };
}
