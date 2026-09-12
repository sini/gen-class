{
  description = "gen-class — pure-Nix class-share mechanism (partition / contract / apply / gate) for the pure-gen module system";

  # Class layering: gen-prelude → gen-class (Class B, deps injected per gen convention §8). gen-class
  # consumes gen-prelude ONLY as a flake input; the tier-2 fixed-input kernel (gen-merge) is INJECTED
  # by the consumer (hub `mkGenLibs.class` passes `merge`), never a flake input here — every tier-1
  # export works with `merge = null`. The library (./lib) is nixpkgs-lib-free (ci/tests/purity.nix)
  # and its public surface never uses the verb `inject` (ci/tests/fence.nix) — den-hoag r2 binds that
  # name to a resolution effect (policy.provide, r2:201).
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
          surface = import ./lib {
            prelude = gen-prelude.lib;
          };
        in
        builtins.deepSeq (builtins.mapAttrs (_: builtins.typeOf) surface) surface;
    };
}
