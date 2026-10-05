# THE DOOR CHECKS (den-hoag-7gp66 P2 — `prelude.door`, R7 argument structure / R5 field closure) —
# every published step of gen-class that takes a RECORD catches its own violations, at its own
# application, catchably.
#
# After P2 a door step is one of two kinds (spec §p2.3.1):
#   · an OPTIONS step — one closed set, first in the call: `mkClass { archetype?; } key members` and
#     `applyCoreFixed { engineArgs?; } core modules`;
#   · a RECORD step — open, all fields required (R5): `mkCoreRecord`, `mkCore` and `invariantUnder`
#     (the keyed-record ruling: two or more configuration operands with no natural order), and the
#     R7(b) pair records behind `gateCore core` and `compareCounters mode`.
# `mkClasses keyOf nodes`, `applyCoreMerge core memberProjection` and `applyCoreExtend core extend` are
# positional (rule 4): their arity is structural and they carry no row. No record step sits behind an
# options step, so no door carries `optionsStep` (G10 has no row).
#
# WHICH refusal fired is a claim about the message and `tryEval` yields only `success`; the byte
# goldens naming each door (R6) live in `ci/tests-error.nix`'s `flake.testsError`.
{
  genClassWithMerge,
  genMerge,
  prelude,
  ...
}:
let
  gc = genClassWithMerge;
  # `firesAtApplication` forces the door's application to WHNF only — never `deepSeq` — so a check
  # that ran only behind a later field read reads `false` (spec §p2.5, premise 5).
  firesAtApplication = e: !(builtins.tryEval (builtins.seq e null)).success;
  answers = e: (builtins.tryEval (builtins.deepSeq e null)).success;

  cls = gc.mkClass { } "h" [
    "blade"
    "cortex"
  ];
  projections = {
    blade.a = 1;
    cortex.a = 1;
  };
  core = gc.mkCore {
    class = cls;
    projection = "p";
    inherit projections;
  };

  # The options rows: the door, its options, `apply` supplying the operands after the options step,
  # and one non-default option whose value the door's own result carries (G3), read by `observe`.
  optionsRows = {
    mkClass = {
      optional = [ "archetype" ];
      apply =
        f:
        f "h" [
          "blade"
          "cortex"
        ];
      observe = r: r.archetype;
      opt.archetype = "cortex";
    };
    applyCoreFixed = {
      optional = [ "engineArgs" ];
      apply = f: f core [ readsMarker ];
      # The engine's own `prefix` stamps every declared option's location, so the option is
      # observable in the result.
      observe = r: r.options.seen.loc;
      opt.engineArgs.prefix = [ "under" ];
    };
  };
  # `applyCoreFixed`'s observation needs a module declaring an option, so its row applies with one.
  readsMarker = {
    options.seen = genMerge.mkOption { default = 1; };
  };

  # The record rows: the door, its required fields, and one complete record it answers on.
  recordRows = {
    mkCoreRecord = {
      required = [
        "class"
        "projection"
        "sharedKeys"
        "values"
      ];
      good = {
        class = cls;
        projection = "p";
        sharedKeys = [ ];
        values = { };
      };
    };
    mkCore = {
      required = [
        "class"
        "projection"
        "projections"
      ];
      good = {
        class = cls;
        projection = "p";
        inherit projections;
      };
    };
    invariantUnder = {
      required = [
        "class"
        "projection"
        "projections"
      ];
      good = {
        class = cls;
        projection = "p";
        inherit projections;
      };
    };
  };
  # The pair steps behind a positional configuration operand: not top-level doors, so they are read
  # through the step the positional application returns.
  pairRows = {
    gateCore = {
      step = gc.gateCore core;
      required = [
        "candidate"
        "real"
      ];
      good = {
        candidate.a = 1;
        real.a = 1;
      };
    };
    compareCounters = {
      step = gc.compareCounters "exact";
      required = [
        "expected"
        "actual"
      ];
      good = {
        expected.x = 1;
        actual.x = 1;
      };
    };
  };

  # A field name no door declares, generated per evaluation from the door names themselves, so it is
  # never a name any contract below lists.
  stranger =
    "not-a-field-of-"
    + builtins.concatStringsSep "-" (builtins.attrNames (optionsRows // recordRows // pairRows));

  perOptions = f: builtins.mapAttrs f optionsRows;
  perRecord = f: builtins.mapAttrs f recordRows;
  perPair = f: builtins.mapAttrs f pairRows;

  surfaceDoors = builtins.attrNames (
    prelude.filterAttrs (_: v: builtins.isAttrs v && v ? __functor && v ? __contract) gc
  );
in
{
  flake.tests.door-checks = {
    # ── LIVE CONTROLS, first: the predicates are not dead ──
    test-control-firesAtApplication-is-true-for-an-ordinary-throw = {
      expr = firesAtApplication (throw "control probe, not this suite's subject");
      expected = true;
    };
    test-control-firesAtApplication-is-false-for-a-throw-behind-an-unread-field = {
      expr = firesAtApplication { culprit = throw "control probe, not this suite's subject"; };
      expected = false;
    };

    # ── THE TABLE IS THE SURFACE ──
    # Every published door has a row and every row is a published door, so a door added without a
    # row — or a row whose door reverted to a lambda — reds here.
    test-the-door-table-equals-the-surface-doors = {
      expr = surfaceDoors;
      expected = builtins.sort (a: b: a < b) (builtins.attrNames (optionsRows // recordRows));
    };
    test-the-positional-entries-are-plain-lambdas = {
      expr = map (n: builtins.isFunction gc.${n}) [
        "mkClasses"
        "applyCoreMerge"
        "applyCoreExtend"
        "gateCore"
        "compareCounters"
      ];
      expected = [
        true
        true
        true
        true
        true
      ];
    };
    test-control-the-positional-entries-answer = {
      expr = {
        classes = map (c: c.members) (gc.mkClasses (_: _: "k") projections);
        merged = gc.applyCoreMerge core { b = 2; };
        extended = gc.applyCoreExtend core (a: builtins.length a.modules);
      };
      expected = {
        classes = [
          [
            "blade"
            "cortex"
          ]
        ];
        merged = {
          a = 1;
          b = 2;
        };
        extended = 1;
      };
    };

    # ── OPTIONS STEPS ──
    # G1/G4: an unknown option is refused at `f opts`'s WHNF, before any operand.
    test-an-unknown-option-is-refused-at-the-options-application = {
      expr = perOptions (n: _: firesAtApplication (gc.${n} { ${stranger} = 1; }));
      expected = perOptions (_: _: true);
    };
    test-a-non-set-options-argument-is-refused-at-the-application = {
      expr = perOptions (n: _: firesAtApplication (gc.${n} 1));
      expected = perOptions (_: _: true);
    };
    # The old one-record shape is refused by name at its first application: its fields are not
    # options of either door.
    test-the-old-one-record-shape-is-refused-at-the-application = {
      expr = {
        mkClass = firesAtApplication (
          gc.mkClass {
            key = "h";
            members = [ "blade" ];
          }
        );
        applyCoreFixed = firesAtApplication (
          gc.applyCoreFixed {
            inherit core;
            modules = [ ];
          }
        );
      };
      expected = perOptions (_: _: true);
    };
    # The live control: `{ }` forms the door and the operands answer.
    test-control-the-empty-options-answer = {
      expr = perOptions (n: r: answers (r.observe (r.apply (gc.${n} { }))));
      expected = perOptions (_: _: true);
    };
    # Every option of each door is admitted, together.
    test-every-option-is-admitted = {
      expr = perOptions (n: r: !firesAtApplication (gc.${n} (prelude.genAttrs r.optional (_: null))));
      expected = perOptions (_: _: true);
    };
    # D3: the published contract and the functor-aware reader agree with the row.
    test-each-options-door-publishes-its-contract = {
      expr = perOptions (
        n: _: {
          inherit (gc.${n}.__contract) optional open required;
          args = prelude.functionArgs gc.${n};
        }
      );
      expected = perOptions (
        _: r: {
          inherit (r) optional;
          open = false;
          required = [ ];
          args = builtins.listToAttrs (map (f: prelude.nameValuePair f true) r.optional);
        }
      );
    };
    # G3: a non-default option reaches the result (`differ`, against `{ }`), and the partially
    # applied door agrees with the full call (`agree`), each read from its own evaluation.
    test-a-non-default-option-reaches-the-result = {
      expr = perOptions (
        n: r:
        let
          f1 = gc.${n} r.opt;
          run = f: r.observe (r.apply f);
        in
        {
          agree = run f1 == run (gc.${n} r.opt);
          differ = run f1 != run (gc.${n} { });
        }
      );
      expected = perOptions (
        _: _: {
          agree = true;
          differ = true;
        }
      );
    };
    # Composition: `mkClass opts` is a value mapped over keys.
    test-a-partially-applied-door-maps-over-keys = {
      expr = map (c: c.archetype) (
        map
          (
            k:
            gc.mkClass { archetype = "cortex"; } k [
              "blade"
              "cortex"
            ]
          )
          [
            "a"
            "b"
          ]
      );
      expected = [
        "cortex"
        "cortex"
      ];
    };

    # ── RECORD STEPS (R5: open, all fields required) ──
    # D2: a missing required field is refused at the record's application, before any field read.
    test-each-missing-required-field-is-refused-at-the-application = {
      expr = perRecord (
        n: r: map (f: firesAtApplication (gc.${n} (builtins.removeAttrs r.good [ f ]))) r.required
      );
      expected = perRecord (_: r: map (_: true) r.required);
    };
    test-each-pair-missing-field-is-refused-at-the-application = {
      expr = perPair (
        _: r: map (f: firesAtApplication (r.step (builtins.removeAttrs r.good [ f ]))) r.required
      );
      expected = perPair (_: r: map (_: true) r.required);
    };
    # G2: an extra field is admitted, answer unchanged (R5's stated price).
    test-an-extra-field-is-admitted-and-the-answer-is-unchanged = {
      expr = perRecord (n: r: gc.${n} (r.good // { ${stranger} = 1; }) == gc.${n} r.good);
      expected = perRecord (_: _: true);
    };
    test-a-pair-extra-field-is-admitted-and-the-answer-is-unchanged = {
      expr = perPair (_: r: r.step (r.good // { ${stranger} = 1; }) == r.step r.good);
      expected = perPair (_: _: true);
    };
    # D3: the published contract and the reader agree with the row.
    test-each-record-door-publishes-its-contract = {
      expr = perRecord (
        n: _: {
          inherit (gc.${n}.__contract) required open optional;
          args = prelude.functionArgs gc.${n};
        }
      );
      expected = perRecord (
        _: r: {
          inherit (r) required;
          open = true;
          optional = [ ];
          args = builtins.listToAttrs (map (f: prelude.nameValuePair f false) r.required);
        }
      );
    };
    test-each-pair-step-publishes-its-contract = {
      expr = perPair (
        _: r: {
          inherit (r.step.__contract) required open;
        }
      );
      expected = perPair (
        _: r: {
          inherit (r) required;
          open = true;
        }
      );
    };
  };
}
