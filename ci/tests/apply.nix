# Apply suite (plan Task 4): the tier-1 core-application mechanisms lifted from the 7b driver
# (hola ci/bench/class-share-realization.sh) and generalized to N members. Four verb groups:
#   apply-oracle  — mkCore: the presence-guarded byte-identical intersection == the corpus pin.
#   apply-merge   — applyCoreMerge: THE reconstruction identity + the core-owns-sharedKeys semantic.
#   apply-extend  — applyCoreExtend: extendModules force-wrapper wins over the base def (evalModules).
#   apply-probe   — invariantUnder: the leafLike class-invariance probe (the system.path lesson).
# nix-unit compares expr == expected. `nixpkgsLib` supplies the evalModules fixture ONLY (ci-side).
{
  lib,
  genClass,
  nixpkgsLib,
  ...
}:
let
  inherit (genClass)
    mkClass
    mkCore
    applyCoreMerge
    applyCoreExtend
    invariantUnder
    ;
  corpus = import ./_fixtures/corpus.nix { inherit lib; };

  inherit (builtins) toJSON;

  # ── classes over the corpus (archetype = mkClass's deterministic default: head of sorted members) ──
  agentClass = mkClass {
    key = "agent";
    members = corpus.agents.members;
  }; # archetype = agent-0
  heteroClass = mkClass {
    key = "host";
    members = corpus.hetero.members;
  }; # archetype = blade

  agentCore = mkCore {
    class = agentClass;
    inherit (corpus.agents) projection projections;
  };
  heteroCore = mkCore {
    class = heteroClass;
    inherit (corpus.hetero) projection projections;
  };

  # A deliberately-divergent extra member: agent-6 clones agent-0 but tampers one shared key (opt00).
  # The oracle must DROP opt00 ⇒ sharedKeys shrinks from 40 to 39 (a diverging member narrows the core).
  tamperedProjections = corpus.agents.projections // {
    "agent-6" = corpus.agents.projections."agent-0" // {
      opt00 = "TAMPERED";
    };
  };
  divergentClass = mkClass {
    key = "agent";
    members = corpus.agents.members ++ [ "agent-6" ];
  };
  divergentCore = mkCore {
    class = divergentClass;
    inherit (corpus.agents) projection;
    projections = tamperedProjections;
  };

  # Empty-intersection core: two members disagree on their only key ⇒ sharedKeys = [] ⇒ apply = identity.
  emptyCore = mkCore {
    class = mkClass {
      key = "k";
      members = [
        "p"
        "q"
      ];
    };
    projection = "sub";
    projections = {
      p = {
        x = 1;
      };
      q = {
        x = 2;
      };
    };
  };

  # ── applyCoreExtend fixture: a member `system` (evalModules result) whose base defs DIFFER from the
  # core, so the force-wrapper winning is observable. `c` is a member-only axis key under the same
  # subtree — it must SURVIVE (core forces per-key, never clobbers the whole projection subtree). ──
  extendClass = mkClass {
    key = "k";
    members = [
      "m1"
      "m2"
    ];
  }; # archetype = m1
  extendCore = mkCore {
    class = extendClass;
    projection = "sub";
    projections = {
      m1 = {
        a = "core-a";
        b = "core-b";
      };
      m2 = {
        a = "core-a";
        b = "core-b";
      };
    };
  }; # sharedKeys = [ "a" "b" ], values = { a = "core-a"; b = "core-b"; }
  baseSystem = nixpkgsLib.evalModules {
    modules = [
      {
        options.sub = nixpkgsLib.mkOption {
          type = nixpkgsLib.types.attrsOf nixpkgsLib.types.anything;
          default = { };
        };
        config.sub = {
          a = "base-a";
          b = "base-b";
          c = "member-c";
        };
      }
    ];
  };
  extended = applyCoreExtend {
    core = extendCore;
    system = baseSystem;
  };

  # dotted-projection extend: proves applyCoreExtend nests core values under the FULL projection path.
  dottedCore = mkCore {
    class = mkClass {
      key = "k";
      members = [ "m1" ];
    };
    projection = "x.y";
    projections = {
      m1 = {
        a = "core-a";
      };
    };
  };
  dottedSystem = nixpkgsLib.evalModules {
    modules = [
      {
        options.x.y = nixpkgsLib.mkOption {
          type = nixpkgsLib.types.attrsOf nixpkgsLib.types.anything;
          default = { };
        };
        config.x.y = {
          a = "base-a";
        };
      }
    ];
  };
  dottedExtended = applyCoreExtend {
    core = dottedCore;
    system = dottedSystem;
  };

  # ── invariance probe over the leafLike projections ──
  agentProbe = invariantUnder {
    projection = "leaf";
    projections = corpus.agents.leafLike;
    class = agentClass;
  };
  heteroProbe = invariantUnder {
    projection = "leaf";
    projections = corpus.hetero.leafLike;
    class = heteroClass;
  };
in
{
  # ══ mkCore oracle ══════════════════════════════════════════════════════════
  flake.tests.apply-oracle = {
    # (a) homogeneous: the oracle recovers EXACTLY the corpus-declared 40-key shared set. The corpus's
    # declared sharedKeys IS the independent `computedShared` pin (partition.nix self-checks proved
    # they agree), so this equality also pins mkCore == computedShared by construction.
    test-agents-oracle-equals-corpus-pin = {
      expr = agentCore.sharedKeys;
      expected = corpus.agents.sharedKeys;
    };
    test-agents-oracle-count = {
      expr = lib.length agentCore.sharedKeys;
      expected = 40;
    };
    # the per-member deltas (hostname/rank) are NOT byte-identical across members ⇒ excluded.
    test-agents-oracle-excludes-deltas = {
      expr = builtins.elem "hostname" agentCore.sharedKeys || builtins.elem "rank" agentCore.sharedKeys;
      expected = false;
    };

    # (b) heterogeneous: the oracle recovers the 19-key partial set...
    test-hetero-oracle-equals-corpus-pin = {
      expr = heteroCore.sharedKeys;
      expected = corpus.hetero.sharedKeys;
    };
    # ...and EXCLUDES both the byte-divergent keys (value guard) AND the blade-only keys (PRESENCE
    # guard — cortex lacks them, so the `?`-term drops them even though blade has them).
    test-hetero-oracle-excludes-divergent-and-blade-only = {
      expr = builtins.all (k: !(builtins.elem k heteroCore.sharedKeys)) (
        corpus.hetero.divergentKeys ++ corpus.hetero.bladeOnlyKeys
      );
      expected = true;
    };

    # a diverging extra member shrinks the core: opt00 (tampered on agent-6) falls out ⇒ 39 keys.
    test-divergent-member-shrinks-core = {
      expr = lib.length divergentCore.sharedKeys;
      expected = 39;
    };
    test-divergent-member-drops-tampered-key = {
      expr = builtins.elem "opt00" divergentCore.sharedKeys;
      expected = false;
    };

    # values = archetype projection restricted to sharedKeys (byte-comparable subset only).
    test-agents-core-values-are-archetype-restricted = {
      expr = agentCore.values == lib.getAttrs agentCore.sharedKeys corpus.agents.projections."agent-0";
      expected = true;
    };

    # empty intersection ⇒ VALID empty core (documented identity path, not an error).
    test-empty-core-sharedKeys = {
      expr = emptyCore.sharedKeys;
      expected = [ ];
    };
  };

  # ══ applyCoreMerge — reconstruction identity + core-owns-sharedKeys ═════════
  flake.tests.apply-merge = {
    # THE reconstruction identity: applyCoreMerge (core, member) == member byte-identically (toJSON) for
    # EVERY corpus member — core supplies the shared keys, the member its own delta; union == member.
    test-recon-identity-agents = {
      expr = builtins.all (
        m:
        toJSON (applyCoreMerge {
          core = agentCore;
          memberProjection = corpus.agents.projections.${m};
        }) == toJSON corpus.agents.projections.${m}
      ) corpus.agents.members;
      expected = true;
    };
    test-recon-identity-hetero = {
      expr = builtins.all (
        m:
        toJSON (applyCoreMerge {
          core = heteroCore;
          memberProjection = corpus.hetero.projections.${m};
        }) == toJSON corpus.hetero.projections.${m}
      ) corpus.hetero.members;
      expected = true;
    };

    # CORE OWNS sharedKeys (the axis-disjointness discipline manifesting): a member value at a shared key
    # is OVERRIDDEN by the core value — removeAttrs strips the member's copy, core.values supplies it.
    test-core-owns-shared-keys = {
      expr =
        (applyCoreMerge {
          core = heteroCore;
          memberProjection = corpus.hetero.projections.blade // {
            h00 = "member-clobbered";
          };
        }).h00;
      expected = corpus.hetero.projections.blade.h00; # the archetype's shared value, not "member-clobbered"
    };

    # empty core ⇒ applyCoreMerge is IDENTITY (removeAttrs member [] // {} == member).
    test-empty-core-merge-is-identity = {
      expr = applyCoreMerge {
        core = emptyCore;
        memberProjection = {
          x = 2;
          y = 3;
        };
      };
      expected = {
        x = 2;
        y = 3;
      };
    };
  };

  # ══ applyCoreExtend — extendModules force-wrapper equivalence ═══════════════
  flake.tests.apply-extend = {
    # the force-wrapped core values WIN over the member's base defs at the shared keys (a, b), while a
    # member-only axis key (c) under the same subtree SURVIVES (per-key force, not whole-subtree replace).
    test-extend-force-wins-and-preserves-axis = {
      expr = extended.config.sub;
      expected = {
        a = "core-a";
        b = "core-b";
        c = "member-c";
      };
    };
    # dotted projection: core values land under the FULL nested path (x.y), not a flat "x.y" attr.
    test-extend-dotted-projection = {
      expr = dottedExtended.config.x.y;
      expected = {
        a = "core-a";
      };
    };
  };

  # ══ invariantUnder — the leafLike class-invariance probe ════════════════════
  flake.tests.apply-probe = {
    # (a) the leaf is INVARIANT across the homogeneous class ⇒ no diverging keys.
    test-probe-invariant-agents = {
      expr = agentProbe.invariant;
      expected = true;
    };
    test-probe-agents-no-diverging-keys = {
      expr = agentProbe.divergingKeys;
      expected = [ ];
    };
    # (b) the leaf is DIVERGENT across the heterogeneous pair ⇒ flagged, with the right diverging key
    # (`path` — the system.path lesson: a leaf one might naively assume shared is host-specific).
    test-probe-divergent-hetero = {
      expr = heteroProbe.invariant;
      expected = false;
    };
    test-probe-hetero-diverging-keys = {
      expr = heteroProbe.divergingKeys;
      expected = [ "path" ];
    };
  };
}
