{
  description = "gen-class — pure-Nix class-share mechanism (partition / contract / apply / gate) for the pure-gen module system";

  # Class layering: gen-prelude → gen-class (Class B, deps injected per gen convention §8). `merge`
  # is an ORDINARY root formal now (owner-ruled arm A, 2026-09-15: `den-hoag-4dfsv`) — gen-class has
  # two `./lib` formals but this root declares only ONE flake input, because gen-merge already sits
  # in `ci/flake.lock` as the hub's own tier-2 wiring source and adding it HERE would be a second,
  # divergent lock edge for the same dependency rather than a new one. `surface` below is therefore
  # PARTIALLY APPLIED: `merge` is left at `./.`'s own default, which resolves it from `ci/flake.lock`
  # the same three-channel way every other formal on this root does. That means this flake's `.lib`
  # now builds the TIER-2 surface (`applyCoreFixed` live) rather than the historical tier-1
  # (`merge = null`) one — a consumer wanting tier-1 from THIS output overrides it explicitly:
  # `gen-class.lib` is a function only until applied, so `(import gen-class-src {}).functionArgs`-style
  # override is not available at the flake boundary; a tier-1-only consumer imports the root directly
  # (`import gen-class-src { merge = null; }`), which `AGENTS.md` documents.
  # The library (./lib) is nixpkgs-lib-free (ci/tests/purity.nix) and its public surface never uses
  # the verb `inject` (ci/tests/fence.nix) — den-hoag r2 binds that name to a resolution effect
  # (policy.provide, r2:201).
  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";
  };

  outputs =
    { gen-prelude, ... }:
    {
      # `nix flake check` forces the WHNF of every top-level output and nothing deeper, so this root's
      # green quantified over the `lib` SPINE alone: a member of the published surface could throw and
      # the check still exited 0 (measured — den-hoag-z1ta6). Hanging the force on that spine is what
      # makes the green mean "the surface evaluates", and a library needs no new output name for it.
      # The depth is each member's WHNF and no deeper: a retirement tombstone is a published `throw`
      # by design (gen-scope's `buildNodes`), so a deep force is red on a healthy tree.
      lib =
        let
          surface = import ./. {
            prelude = gen-prelude.lib;
          };
        in
        builtins.deepSeq (builtins.mapAttrs (_: builtins.typeOf) surface) surface;
    };
}
