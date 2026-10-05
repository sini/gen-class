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
    mkCoreRecord
    applyCoreMerge
    applyCoreExtend
    applyCoreFixed
    invariantUnder
    gateCore
    compareCounters
    ;

  exactly = msg: "^" + prelude.escapeRegex msg + "$";
  thrown = msg: {
    type = "ThrownError";
    msg = exactly msg;
  };
  forced = x: builtins.deepSeq x x;
  # `forced`'s positive twin: the call evaluates clean rather than aborting.
  admitted = v: (builtins.tryEval (builtins.deepSeq v v)).success;

  cls = mkClass { } "h" [
    "blade"
    "cortex"
  ];
  # `cortex` is a class member with no projection.
  uncovered = {
    blade.a = 1;
  };
  # The function is NESTED: toJSON walks into attrsets and lists, so the guard must too.
  functional = {
    blade.f.g = [ (x: x) ];
    cortex.f.g = [ (x: x) ];
  };

  # Minimal shared fixtures for the door-refusals family below: `blade`/`cortex` agree on `a`, so
  # `mkCore` yields a one-key core to feed `applyCoreMerge` / `applyCoreExtend` / `invariantUnder` /
  # `gateCore`. `fakeArtifact` stands in for a nixpkgs `evalModules` result — just enough surface
  # (`.extendModules`, handed as `extend`) for `applyCoreExtend`'s extra-field-admitted cell to evaluate
  # clean, and the artifact itself, handed where `extend` belongs, is the honest non-function mistake.
  sharedProjections = {
    blade.a = 1;
    cortex.a = 1;
  };
  core1 = mkCore {
    class = cls;
    projection = "p";
    projections = sharedProjections;
  };
  fakeArtifact = {
    extendModules = _: { extended = true; };
  };
in
{
  flake.testsError.refusals = {
    test-mkClasses-refuses-non-string-key = {
      expr = forced (mkClasses (_: _: 1) { web = { }; });
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

  # ── door-refusals (den-hoag-7gp66 P2) ──
  # Every gen-class step that takes a RECORD is a `prelude.door`, so a missing required field or an
  # unknown option is refused BY NAME, catchably, at that step's own application. RECORD steps
  # (`mkCoreRecord`, `mkCore`, `invariantUnder`, and the pair records of `gateCore core` and
  # `compareCounters mode`) stay OPEN past their required set — R5's stated price, an extra field is
  # admitted and never reported — so each gets a paired extra-field-admitted control. OPTIONS steps
  # (`mkClass`, `applyCoreFixed`) are closed, so each gets an unknown-option cell, and the old
  # one-record shape is refused by name at its first application: its fields are not options.
  # `mkClasses`, `applyCoreMerge` and `applyCoreExtend` are positional and carry no row here.
  flake.testsError.door-refusals = {
    # ── record steps: missing required field refused, extra field admitted ──
    test-mkCoreRecord-missing-field-named = {
      expr = forced (mkCoreRecord {
        class = cls;
        projection = "p";
        sharedKeys = [ ];
      });
      expectedError = thrown "gen-class.mkCoreRecord: required field 'values' is missing (required: 'class', 'projection', 'sharedKeys', 'values') (in prelude.checkRequired)";
    };
    test-mkCoreRecord-extra-field-admitted = {
      expr = admitted (mkCoreRecord {
        class = cls;
        projection = "p";
        sharedKeys = [ ];
        values = { };
        extra = 1;
      });
      expected = true;
    };

    test-mkCore-missing-field-named = {
      expr = forced (mkCore {
        class = cls;
        projection = "p";
      });
      expectedError = thrown "gen-class.mkCore: required field 'projections' is missing (required: 'class', 'projection', 'projections') (in prelude.checkRequired)";
    };
    test-mkCore-extra-field-admitted = {
      expr = admitted (mkCore {
        class = cls;
        projection = "p";
        projections = sharedProjections;
        extra = 1;
      });
      expected = true;
    };

    test-invariantUnder-missing-field-named = {
      expr = forced (invariantUnder {
        projection = "p";
        projections = sharedProjections;
      });
      expectedError = thrown "gen-class.invariantUnder: required field 'class' is missing (required: 'class', 'projection', 'projections') (in prelude.checkRequired)";
    };
    test-invariantUnder-extra-field-admitted = {
      expr = admitted (invariantUnder {
        projection = "p";
        projections = sharedProjections;
        class = cls;
        extra = 1;
      });
      expected = true;
    };

    test-gateCore-missing-field-named = {
      expr = forced (gateCore core1 { candidate.a = 1; });
      expectedError = thrown "gen-class.gateCore: required field 'real' is missing (required: 'candidate', 'real') (in prelude.checkRequired)";
    };
    test-gateCore-extra-field-admitted = {
      expr = admitted (
        gateCore core1 {
          candidate.a = 1;
          real.a = 1;
          extra = 1;
        }
      );
      expected = true;
    };
    # The old one-record shape: `core` handed where the core belongs is a record, so `isCore` refuses
    # it by name once the pair step is applied.
    test-gateCore-old-one-record-shape-named = {
      expr = forced (
        gateCore
          {
            core = core1;
            candidate.a = 1;
            real.a = 1;
          }
          {
            candidate.a = 1;
            real.a = 1;
          }
      );
      expectedError = thrown "gen-class: gateCore: core must be a gen-class/core record";
    };

    test-compareCounters-missing-field-named = {
      expr = forced (compareCounters "exact" { expected.x = 1; });
      expectedError = thrown "gen-class.compareCounters: required field 'actual' is missing (required: 'expected', 'actual') (in prelude.checkRequired)";
    };
    test-compareCounters-extra-field-admitted = {
      expr = admitted (
        compareCounters "exact" {
          expected.x = 1;
          actual.x = 1;
          extra = 1;
        }
      );
      expected = true;
    };

    # ── options steps: unknown option refused; the old one-record shape refused by name ──
    test-mkClass-unknown-option-named = {
      expr = forced (mkClass {
        extra = 1;
      });
      expectedError = thrown "gen-class.mkClass: 'extra' is not an option of this door; the options are closed (accepted: 'archetype') (in prelude.checkOptions)";
    };
    test-mkClass-old-one-record-shape-named = {
      expr = forced (mkClass {
        key = "h";
        members = [ "a" ];
      });
      expectedError = thrown "gen-class.mkClass: 'key' is not an option of this door; the options are closed (accepted: 'archetype') (in prelude.checkOptions)";
    };

    test-applyCoreFixed-unknown-option-named = {
      expr = forced (applyCoreFixed {
        extra = 1;
      });
      expectedError = thrown "gen-class.applyCoreFixed: 'extra' is not an option of this door; the options are closed (accepted: 'engineArgs') (in prelude.checkOptions)";
    };
    test-applyCoreFixed-old-one-record-shape-named = {
      expr = forced (applyCoreFixed {
        core = core1;
        modules = [ ];
      });
      expectedError = thrown "gen-class.applyCoreFixed: 'core' is not an option of this door; the options are closed (accepted: 'engineArgs') (in prelude.checkOptions)";
    };
  };
}
