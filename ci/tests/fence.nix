# Naming fence (design spec §0 / §2.4): the gen-class PUBLIC surface never uses the verb `inject` —
# den-hoag r2 binds that name to a resolution effect (policy.provide, r2:201). Verbs are `mkClasses`
# / `mkCore` / `applyCore*` / `gateCore`. This check has TEETH: a poisoned fixture attrset MUST be
# caught, else the fence is vacuous.
#
# Enforced surface: the public attribute NAMES of `genClass` + the lib/ FILE NAMES (case-insensitive
# substring `inject`). Arg/field names are fenced by convention (spec §2.4) but are not attrset-
# introspectable at eval time, so they are covered by review, not this check.
{ lib, genClass, ... }:
let
  hasInject = name: lib.hasInfix "inject" (lib.toLower name);
  violationsIn = names: lib.filter hasInject names;

  # File names, not just directory entries whose type is regular — readDir keys are the names.
  libFileNames = builtins.attrNames (builtins.readDir ../../lib);
  publicNames = builtins.attrNames genClass;

  # TEETH fixture: a public surface that WOULD violate the fence. The check must flag it, proving
  # the assertion is not vacuously satisfied by the (currently empty) stub surface.
  poisoned = {
    mkClasses = null;
    injectCore = null; # the poison — MUST be caught
  };
in
{
  flake.tests.fence.test-public-surface-has-no-inject = {
    expr = violationsIn (publicNames ++ libFileNames);
    expected = [ ];
  };

  # The fence must FAIL on a poisoned attrset (else it proves nothing).
  flake.tests.fence.test-fence-catches-poison = {
    expr = violationsIn (builtins.attrNames poisoned);
    expected = [ "injectCore" ];
  };
}
