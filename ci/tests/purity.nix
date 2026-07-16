# Purity invariant (design spec §2.4): the gen-class library (./lib) is nixpkgs-lib-free. The tier-1
# mechanisms are plain data + `prelude` (sha256 / toJSON); the tier-2 kernel is the INJECTED
# gen-merge `merge` value, never a nixpkgs `lib`. `applyCoreExtend` (Task 4) hand-builds the override
# record `{ _type = "override"; priority = 50; content = v; }` rather than calling nixpkgs `mkForce`.
# A stray `lib.`/`evalModules`/`nixpkgs` tether in the library source fails CI.
#
# Scope: lib/**.nix + the root flake.nix + default.nix. NOT ci/ (the harness + the applyCoreExtend
# reference side legitimately use nixpkgs.lib).
{ genPrelude, lib, ... }:
let
  libDir = ../../lib;

  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  walk =
    dir:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        if type == "directory" then
          walk (dir + "/${name}")
        else if lib.hasSuffix ".nix" name then
          [ (dir + "/${name}") ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  sources =
    map (p: {
      name = toString p;
      code = stripComments (builtins.readFile p);
    }) (walk libDir)
    ++
      map
        (rel: {
          name = rel;
          code = stripComments (builtins.readFile (../.. + "/${rel}"));
        })
        [
          "flake.nix"
          "default.nix"
        ];

  # The nixpkgs / module-system tether. gen-class defines no nixpkgs replacements, so the whole
  # `lib.`/`evalModules`/`nixpkgs` surface is forbidden in the library source.
  forbidden = [
    "nixpkgs"
    "lib.types"
    "lib.mkOption"
    "lib.mkMerge"
    "lib.mkForce"
    "lib.evalModules"
    "evalModules"
    "{ lib }"
    "{ lib,"
  ];

  violations = lib.concatMap (
    src:
    map (tok: "${src.name}: '${tok}'") (lib.filter (tok: genPrelude.hasInfix tok src.code) forbidden)
  ) sources;
in
{
  flake.tests.purity.test-library-source-is-nixpkgs-free = {
    expr = violations;
    expected = [ ];
  };
}
