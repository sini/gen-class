# THE ERROR PLANE — cells whose subject is a refusal MESSAGE, read by
# `nix-unit --flake ./ci#testsError`.
#
# Three caller-input mistakes used to abort as evaluator errors that escape `tryEval`: `keyOf`
# returning a non-string (groupBy's type error), `projections` missing a class member (an attribute
# miss), and a compared projection value holding a function (toJSON's abort). mkClass refuses its own
# caller mistakes with a `throw`, so the lib now refuses these three the same way, and each cell pins
# WHICH refusal fired — `tryEval` discards the text, so a boolean cell is satisfied by any throw.
#
# ★ WHY A SECOND OUTPUT. The batch asserter behind `checks.default` forces every `flake.tests` expr
# unconditionally, so a throwing expr there CRASHES the gate rather than failing a cell. This file is
# outside `./tests` (the whole of `testModules`), which keeps the split structural.
#
# ★ `expectedError.msg` IS SEARCHED, NOT WHOLE-MATCHED, so every pattern is anchored at both ends and
# built by escaping the literal text: a prefix pattern would agree with the rewording it exists to catch.
{ genClass, prelude, ... }:
let
  inherit (genClass)
    mkClass
    mkClasses
    mkCore
    invariantUnder
    ;

  exactly = msg: "^" + prelude.escapeRegex msg + "$";
  thrown = msg: {
    type = "ThrownError";
    msg = exactly msg;
  };
  forced = x: builtins.deepSeq x x;

  cls = mkClass {
    key = "h";
    members = [
      "blade"
      "cortex"
    ];
  };
  # `cortex` is a class member with no projection.
  uncovered = {
    blade.a = 1;
  };
  # The function is NESTED: toJSON walks into attrsets and lists, so the guard must too.
  functional = {
    blade.f.g = [ (x: x) ];
    cortex.f.g = [ (x: x) ];
  };
in
{
  flake.testsError.refusals = {
    test-mkClasses-refuses-non-string-key = {
      expr = forced (mkClasses {
        nodes.web = { };
        keyOf = _: _: 1;
      });
      expectedError = thrown ''gen-class: mkClasses: keyOf must return a string (got int for node "web")'';
    };
    test-mkCore-refuses-uncovered-member = {
      expr = forced (mkCore {
        class = cls;
        projection = "p";
        projections = uncovered;
      });
      expectedError = thrown ''gen-class: mkCore: projections must cover class.members (missing ["cortex"])'';
    };
    test-mkCore-refuses-function-value = {
      expr = forced (mkCore {
        class = cls;
        projection = "p";
        projections = functional;
      });
      expectedError = thrown "gen-class: mkCore: projections.blade.f must be toJSON-serialisable (it holds a function)";
    };
    test-invariantUnder-refuses-uncovered-member = {
      expr = forced (invariantUnder {
        class = cls;
        projection = "p";
        projections = uncovered;
      });
      expectedError = thrown ''gen-class: invariantUnder: projections must cover class.members (missing ["cortex"])'';
    };
    test-invariantUnder-refuses-function-value = {
      expr = forced (invariantUnder {
        class = cls;
        projection = "p";
        projections = functional;
      });
      expectedError = thrown "gen-class: invariantUnder: projections.blade.f must be toJSON-serialisable (it holds a function)";
    };
  };
}
