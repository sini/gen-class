{
  inputs = {
    gen.url = "github:sini/gen";
    gen-prelude.url = "github:sini/gen-prelude";
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
      ...
    }:
    let
      # Tier-1 surface: gen-class with prelude only (merge = null). Tier-2 suites (Task 7) build a
      # second `genClassWithMerge` specialArg once gen-merge is wired.
      genClass = import ../lib {
        prelude = gen-prelude.lib;
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
          nixpkgsLib
          ;
      };
    };
}
