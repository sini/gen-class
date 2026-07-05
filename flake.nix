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
      lib = import ./lib {
        prelude = gen-prelude.lib;
      };
    };
}
