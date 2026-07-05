# Contract suite (plan Task 2): Class/Core/Axis constructors + EVERY validation throw + the two
# determinism claims (default-archetype rule; digest canonicality/stability). Throws use the
# tryEval/deepSeq/success idiom (gen-merge merge.nix convention); nix-unit compares expr==expected.
{ genClass, ... }:
let
  inherit (genClass) mkClass mkCoreRecord;

  # Throw-probe: forces `e` fully and reports whether evaluation FAILED. Mirrors gen-merge's
  # `(tryEval (deepSeq e null)).success == false` pattern, inverted to read as "did throw".
  didThrow = e: !(builtins.tryEval (builtins.deepSeq e null)).success;

  cls = mkClass {
    key = "k";
    members = [
      "a"
      "b"
    ];
  };

  vals = {
    a = 1;
    b = 2;
  };
  valsReordered = {
    b = 2;
    a = 1;
  };
  valsChanged = {
    a = 1;
    b = 3;
  };
  core = mkCoreRecord {
    class = cls;
    projection = "systemd.units";
    sharedKeys = [
      "a"
      "b"
    ];
    values = vals;
  };
in
{
  # ── mkClass: happy paths + the deterministic archetype rule ──
  flake.tests.contract-class = {
    test-record-shape = {
      expr = mkClass {
        key = "hosts";
        members = [
          "b"
          "a"
        ];
      };
      # members preserved as-given (partition sorts upstream); archetype = head (sort members).
      expected = {
        _type = "gen-class/class";
        key = "hosts";
        members = [
          "b"
          "a"
        ];
        archetype = "a";
      };
    };

    # DETERMINISTIC RULE: default archetype = head (sort lessThan members), input-order independent.
    test-default-archetype-lexicographic = {
      expr =
        (mkClass {
          key = "k";
          members = [
            "cortex"
            "blade"
            "axon"
          ];
        }).archetype;
      expected = "axon";
    };
    test-default-archetype-permutation-invariant = {
      expr =
        (mkClass {
          key = "k";
          members = [
            "cortex"
            "blade"
            "axon"
          ];
        }).archetype == (mkClass {
          key = "k";
          members = [
            "blade"
            "axon"
            "cortex"
          ];
        }).archetype;
      expected = true;
    };
    test-explicit-archetype-honored = {
      expr =
        (mkClass {
          key = "k";
          members = [
            "a"
            "b"
            "c"
          ];
          archetype = "c";
        }).archetype;
      expected = "c";
    };

    # every validation throw
    test-throws-non-string-key = {
      expr = didThrow (mkClass {
        key = 5;
        members = [ "a" ];
      });
      expected = true;
    };
    test-throws-empty-members = {
      expr = didThrow (mkClass {
        key = "k";
        members = [ ];
      });
      expected = true;
    };
    test-throws-members-not-list = {
      expr = didThrow (mkClass {
        key = "k";
        members = "a";
      });
      expected = true;
    };
    test-throws-archetype-not-member = {
      expr = didThrow (mkClass {
        key = "k";
        members = [
          "a"
          "b"
        ];
        archetype = "z";
      });
      expected = true;
    };
  };

  # ── mkCoreRecord: happy paths, digest determinism, empty-core identity, every validation throw ──
  flake.tests.contract-core = {
    test-record-shape = {
      expr = {
        inherit (core)
          _type
          projection
          sharedKeys
          values
          ;
        classType = core.class._type;
        digestType = builtins.typeOf core.digest;
      };
      expected = {
        _type = "gen-class/core";
        projection = "systemd.units";
        sharedKeys = [
          "a"
          "b"
        ];
        values = {
          a = 1;
          b = 2;
        };
        classType = "gen-class/class";
        digestType = "string";
      };
    };

    # empty intersection ⇒ VALID core (apply becomes identity; documented, not an error).
    test-empty-core-valid = {
      expr =
        (mkCoreRecord {
          class = cls;
          projection = "p";
          sharedKeys = [ ];
          values = { };
        })._type;
      expected = "gen-class/core";
    };

    # CANONICALITY: digest = sha256 of sorted-key toJSON — matches a hand computation.
    test-digest-matches-canonical = {
      expr = core.digest == builtins.hashString "sha256" (builtins.toJSON vals);
      expected = true;
    };
    # STABILITY: equal values ⇒ equal digest (source key-order is irrelevant — toJSON is sorted).
    test-digest-key-order-invariant = {
      expr =
        core.digest == (mkCoreRecord {
          class = cls;
          projection = "systemd.units";
          sharedKeys = [
            "a"
            "b"
          ];
          values = valsReordered;
        }).digest;
      expected = true;
    };
    # SENSITIVITY: a changed value ⇒ a changed digest.
    test-digest-changes-on-value-change = {
      expr =
        core.digest != (mkCoreRecord {
          class = cls;
          projection = "systemd.units";
          sharedKeys = [
            "a"
            "b"
          ];
          values = valsChanged;
        }).digest;
      expected = true;
    };

    # every validation throw
    test-throws-non-class = {
      expr = didThrow (mkCoreRecord {
        class = {
          not = "a class";
        };
        projection = "p";
        sharedKeys = [ ];
        values = { };
      });
      expected = true;
    };
    test-throws-non-string-projection = {
      expr = didThrow (mkCoreRecord {
        class = cls;
        projection = 5;
        sharedKeys = [ ];
        values = { };
      });
      expected = true;
    };
    test-throws-unsorted-sharedKeys = {
      expr = didThrow (mkCoreRecord {
        class = cls;
        projection = "p";
        sharedKeys = [
          "b"
          "a"
        ];
        values = {
          a = 1;
          b = 2;
        };
      });
      expected = true;
    };
    test-throws-duplicate-sharedKeys = {
      expr = didThrow (mkCoreRecord {
        class = cls;
        projection = "p";
        sharedKeys = [
          "a"
          "a"
        ];
        values = {
          a = 1;
        };
      });
      expected = true;
    };
    test-throws-keys-mismatch = {
      expr = didThrow (mkCoreRecord {
        class = cls;
        projection = "p";
        sharedKeys = [
          "a"
          "b"
        ];
        values = {
          a = 1;
        };
      });
      expected = true;
    };
  };
}
