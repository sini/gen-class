# Partition suite (plan Task 3). Two suites:
#   `corpus`    — self-checks that PIN the synthetic corpus's designed shape (recomputed independently
#                 of the lib under test, so the fixture every later suite consumes is trustworthy).
#   `partition` — mkClasses grouping / determinism / singleton passthrough / member-sort / archetype.
# nix-unit compares expr == expected.
{ lib, genClass, ... }:
let
  inherit (genClass) mkClasses;
  corpus = import ./_fixtures/corpus.nix { inherit lib; };

  inherit (builtins) lessThan sort;

  # The byte-identical-intersection oracle, recomputed HERE (independent of apply.nix, Task 4) purely
  # to verify the corpus: keys present in every member AND toJSON-equal to the archetype's value.
  computedShared =
    {
      members,
      archetype,
      projections,
    }:
    let
      archProj = projections.${archetype};
    in
    sort lessThan (
      lib.filter (
        k:
        lib.all (
          m:
          builtins.hasAttr k projections.${m}
          && builtins.toJSON projections.${m}.${k} == builtins.toJSON archProj.${k}
        ) members
      ) (builtins.attrNames archProj)
    );

  # ── partition inputs ──
  classes = mkClasses { inherit (corpus) nodes keyOf; };
  classByKey = k: builtins.head (lib.filter (c: c.key == k) classes);

  # Same fleet, rebuilt from reversed name/value pairs ⇒ a different construction path, identical value
  # (Nix attrsets are key-ordered). Demonstrates permutation-determinism of the OUTPUT list.
  permutedNodes = builtins.listToAttrs (
    lib.reverseList (lib.mapAttrsToList lib.nameValuePair corpus.nodes)
  );
in
{
  # ══ corpus self-checks ═════════════════════════════════════════════════════
  flake.tests.corpus = {
    # (a) homogeneous: 6 members.
    test-agents-member-count = {
      expr = lib.length corpus.agents.members;
      expected = 6;
    };
    # (a) the designed shared subtree is 40 keys...
    test-agents-shared-key-count = {
      expr = lib.length corpus.agents.sharedKeys;
      expected = 40;
    };
    # ...and the INDEPENDENTLY-computed byte-identical intersection equals the declared sharedKeys
    # (i.e. the corpus's core is real, not merely asserted).
    test-agents-computed-shared-equals-declared = {
      expr = computedShared {
        inherit (corpus.agents) members projections;
        archetype = "agent-0";
      };
      expected = corpus.agents.sharedKeys;
    };
    # (a) the per-member deltas genuinely vary (else they'd wrongly land in the core).
    test-agents-deltas-differ = {
      expr = lib.length (
        lib.unique (map (m: corpus.agents.projections.${m}.hostname) corpus.agents.members)
      );
      expected = 6;
    };
    # (a) leafLike INVARIANT: all six agents carry one identical leaf value.
    test-agents-leaf-invariant = {
      expr = lib.length (
        lib.unique (map (m: builtins.toJSON corpus.agents.leafLike.${m}) corpus.agents.members)
      );
      expected = 1;
    };

    # (b) PRESENCE guard: blade has a key cortex lacks.
    test-hetero-presence-guard = {
      expr =
        let
          k = builtins.head corpus.hetero.bladeOnlyKeys;
        in
        builtins.hasAttr k corpus.hetero.projections.blade
        && !builtins.hasAttr k corpus.hetero.projections.cortex;
      expected = true;
    };
    # (b) the byte-identical intersection is 19 keys, and matches the declared sharedKeys — the
    # divergent + blade-only keys are correctly excluded.
    test-hetero-computed-shared-equals-declared = {
      expr = computedShared {
        inherit (corpus.hetero) members projections archetype;
      };
      expected = corpus.hetero.sharedKeys;
    };
    test-hetero-shared-key-count = {
      expr = lib.length corpus.hetero.sharedKeys;
      expected = 19;
    };
    # (b) ~76% overlap: 19 shared of blade's 25 total keys (integer arithmetic: 19*100/25 == 76).
    test-hetero-overlap-76pct = {
      expr =
        (lib.length corpus.hetero.sharedKeys) * 100
        / (lib.length (builtins.attrNames corpus.hetero.projections.blade));
      expected = 76;
    };
    # (b) the divergent keys are present in BOTH members but differ (present-and-diverging, not absent).
    test-hetero-divergent-present-both-differ = {
      expr = lib.all (
        k:
        builtins.hasAttr k corpus.hetero.projections.blade
        && builtins.hasAttr k corpus.hetero.projections.cortex
        && corpus.hetero.projections.blade.${k} != corpus.hetero.projections.cortex.${k}
      ) corpus.hetero.divergentKeys;
      expected = true;
    };
    # (c) leafLike DIVERGENT across (b).
    test-hetero-leaf-divergent = {
      expr = corpus.hetero.leafLike.blade != corpus.hetero.leafLike.cortex;
      expected = true;
    };
  };

  # ══ mkClasses ══════════════════════════════════════════════════════════════
  flake.tests.partition = {
    # grouping correctness on a small inline fleet (keyOf reads the node value directly).
    test-grouping-basic = {
      expr = map (c: { inherit (c) key members; }) (mkClasses {
        nodes = {
          x = "A";
          y = "B";
          z = "A";
        };
        keyOf = _: v: v;
      });
      expected = [
        {
          key = "A";
          members = [
            "x"
            "z"
          ];
        }
        {
          key = "B";
          members = [ "y" ];
        }
      ];
    };

    # corpus fleet ⇒ three classes, keys in sorted order.
    test-class-keys-sorted = {
      expr = map (c: c.key) classes;
      expected = [
        "agent"
        "host"
        "solo"
      ];
    };
    test-agent-class-members = {
      expr = (classByKey "agent").members;
      expected = [
        "agent-0"
        "agent-1"
        "agent-2"
        "agent-3"
        "agent-4"
        "agent-5"
      ];
    };
    test-host-class-members = {
      expr = (classByKey "host").members;
      expected = [
        "blade"
        "cortex"
      ];
    };

    # singleton passthrough: a lone node becomes a 1-member class record (uniform shape, no special case).
    test-singleton-passthrough = {
      expr = (classByKey "solo").members;
      expected = [ "lonely" ];
    };
    test-singleton-is-class-record = {
      expr = (classByKey "solo")._type;
      expected = "gen-class/class";
    };

    # every class carries SORTED members (partition owns member order; mkClass stores as-given).
    test-all-members-sorted = {
      expr = lib.all (c: c.members == sort lessThan c.members) classes;
      expected = true;
    };
    # the sort is real, not an artefact of pre-sorted input: names that group out-of-order come back sorted.
    test-members-sorted-nontrivial = {
      expr =
        (builtins.head (mkClasses {
          nodes = {
            zeta = "g";
            alpha = "g";
            mid = "g";
          };
          keyOf = _: v: v;
        })).members;
      expected = [
        "alpha"
        "mid"
        "zeta"
      ];
    };

    # archetype = mkClass's deterministic default (head of sorted members).
    test-agent-archetype = {
      expr = (classByKey "agent").archetype;
      expected = "agent-0";
    };
    test-host-archetype = {
      expr = (classByKey "host").archetype;
      expected = "blade";
    };

    # determinism: a permuted-construction of the same fleet yields a byte-identical class list.
    test-permutation-determinism = {
      expr =
        mkClasses {
          nodes = permutedNodes;
          inherit (corpus) keyOf;
        } == classes;
      expected = true;
    };
    # keyOf may DERIVE a key (not just read one); grouping follows the derived key.
    test-derived-keyof = {
      expr = map (c: c.key) (mkClasses {
        nodes = {
          n1 = 10;
          n2 = 3;
          n3 = 20;
        };
        keyOf = _: v: if v >= 10 then "big" else "small";
      });
      expected = [
        "big"
        "small"
      ];
    };
  };
}
