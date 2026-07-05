{
  inputs = {
    gen.url = "github:sini/gen";
    gen-prelude.url = "github:sini/gen-prelude";
    # The tier-2 fixed-input kernel (spec §2.5). gen-merge.lib self-wires its own prelude + gen-types
    # (gen-merge/flake.nix), so the ci consumes `gen-merge.lib` directly — no manual wiring. It enters
    # ONLY here (a VALUE injected into `genClassWithMerge` + the apply-fixed fixtures); the library
    # (../lib) never takes gen-merge as a flake input — the consumer injects it (flake.nix boundary).
    gen-merge.url = "github:sini/gen-merge";
    # nixpkgs is the CI runner's dependency (nix-unit harness, treefmt) and supplies the `lib` the
    # test modules use — plus `nixpkgsLib` for the fixture-assembly / applyCoreExtend equivalence
    # side (spec §2.3). nixpkgs enters ONLY here (a VALUE in ci/), never a `lib/` dep — the library
    # (../lib) is nixpkgs-lib-free (ci/tests/purity.nix enforces this).
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{
      gen,
      gen-prelude,
      gen-merge,
      ...
    }:
    let
      # Tier-1 surface: gen-class with prelude only (merge = null) — the merge==null clear-error path.
      genClass = import ../lib {
        prelude = gen-prelude.lib;
      };
      # Tier-2 surface: the SAME lib wired with the injected gen-merge kernel — `applyCoreFixed` (Task 7).
      genClassWithMerge = import ../lib {
        prelude = gen-prelude.lib;
        merge = gen-merge.lib;
      };
      nixpkgsLib = import "${inputs.nixpkgs}/lib";
    in
    gen.lib.mkCi {
      inherit inputs;
      name = "gen-class";
      testModules = ./tests;
      specialArgs = {
        inherit
          genClass
          genClassWithMerge
          nixpkgsLib
          ;
        # The raw kernel — the apply-fixed suite builds engine fixtures (throwing-merge skip proof,
        # plain-values reference modules) directly against it. ci-side value only, never a `lib/` dep.
        genMerge = gen-merge.lib;
      };
    };
}
