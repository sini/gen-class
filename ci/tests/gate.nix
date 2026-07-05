# Gate suite (plan Task 5): the hard-fail byte gate + the pure half of the two-tier STOP-on-diff
# counter policy (spec §2.4). Two verb groups:
#   gate-core     — gateCore: passes on THE reconstruction identity (both corpus shapes, every
#                   member); TEETH — a corrupted core value ⇒ gate false + digests differ; coreCount.
#   compare-*     — compareCounters: exact catches ±1; band swallows the −8-on-20M build drift but
#                   FAILS a real 2× regression; mixed per-counter verdicts ⇒ overall fail.
# nix-unit compares expr == expected. `nixpkgsLib` unused here; `lib` only for `length`.
{
  lib,
  genClass,
  ...
}:
let
  inherit (genClass)
    mkClass
    mkCore
    applyCoreMerge
    gateCore
    compareCounters
    ;
  corpus = import ./_fixtures/corpus.nix { inherit lib; };

  # ── cores over the corpus (archetype = mkClass's deterministic default) ──
  agentClass = mkClass {
    key = "agent";
    members = corpus.agents.members;
  };
  heteroClass = mkClass {
    key = "host";
    members = corpus.hetero.members;
  };
  agentCore = mkCore {
    class = agentClass;
    inherit (corpus.agents) projection projections;
  };
  heteroCore = mkCore {
    class = heteroClass;
    inherit (corpus.hetero) projection projections;
  };

  # THE reconstruction identity, gated: candidate = applyCoreMerge (core, member); real = member. The
  # oracle rebuilds the member byte-identically ⇒ digests match ⇒ gate true. Run over every member.
  gateMember =
    core: projections: m:
    gateCore {
      inherit core;
      candidate = applyCoreMerge {
        inherit core;
        memberProjection = projections.${m};
      };
      real = projections.${m};
    };

  # TEETH: a corrupted core (one shared value tampered) reconstructs a member that DIFFERS from the
  # real one ⇒ gate false, digests differ. `agentCore` shares opt00 = "shared-opt00"; poison it.
  corruptedAgentCore = agentCore // {
    values = agentCore.values // {
      opt00 = "CORRUPTED";
    };
  };
  teethGate = gateCore {
    core = corruptedAgentCore;
    candidate = applyCoreMerge {
      core = corruptedAgentCore;
      memberProjection = corpus.agents.projections."agent-0";
    };
    real = corpus.agents.projections."agent-0";
  };

  # ── compareCounters fixtures (the two-tier policy's pure half) ──
  # exact: identical ⇒ pass; off-by-one ⇒ fail (same-build determinism, no tolerance).
  exactPass = compareCounters {
    expected = {
      nrPrimOpCalls = 100;
    };
    actual = {
      nrPrimOpCalls = 100;
    };
    mode = "exact";
  };
  exactOffByOne = compareCounters {
    expected = {
      nrPrimOpCalls = 100;
    };
    actual = {
      nrPrimOpCalls = 101;
    };
    mode = "exact";
  };

  # band: the Determinate-vs-CppNix −8-on-20M build drift (~4e-7 relative) is INSIDE ±0.1% ⇒ pass.
  bandTinyDrift = compareCounters {
    expected = {
      nrPrimOpCalls = 20000000;
    };
    actual = {
      nrPrimOpCalls = 19999992;
    }; # −8
    mode = {
      band = 0.001;
    };
  };
  # band: a real 2× blowup (relative delta 1.0) is OUTSIDE the band ⇒ fail (the O(k²) regression).
  bandRegression = compareCounters {
    expected = {
      nrPrimOpCalls = 1000000;
    };
    actual = {
      nrPrimOpCalls = 2000000;
    };
    mode = {
      band = 0.001;
    };
  };
  # mixed: one counter drifts within band (pass), one doubles (fail) ⇒ overall fail; per-counter split.
  bandMixed = compareCounters {
    expected = {
      a = 1000000;
      b = 500000;
    };
    actual = {
      a = 999999; # −1, within band
      b = 1000000; # 2×, outside band
    };
    mode = {
      band = 0.001;
    };
  };
in
{
  # ══ gateCore — reconstruction identity, teeth, coreCount ═════════════════════
  flake.tests.gate-core = {
    # THE identity gate: every agent member reconstructs byte-identically ⇒ gate true.
    test-gate-passes-agents = {
      expr = builtins.all (
        m: (gateMember agentCore corpus.agents.projections m).gate
      ) corpus.agents.members;
      expected = true;
    };
    # ...and every hetero member (the 76%-shared pair): axis keys carry the divergence, gate still true.
    test-gate-passes-hetero = {
      expr = builtins.all (
        m: (gateMember heteroCore corpus.hetero.projections m).gate
      ) corpus.hetero.members;
      expected = true;
    };
    # digests are EQUAL on the identity (the byte gate's basis, not just the derived bool).
    test-gate-identity-digests-equal =
      let
        g = gateMember agentCore corpus.agents.projections "agent-3";
      in
      {
        expr = g.candidateDigest == g.realDigest;
        expected = true;
      };
    # coreCount = length core.sharedKeys (evidence: the 40-key agent core, 19-key hetero core).
    test-gate-coreCount-agents = {
      expr = (gateMember agentCore corpus.agents.projections "agent-0").coreCount;
      expected = 40;
    };
    test-gate-coreCount-hetero = {
      expr = (gateMember heteroCore corpus.hetero.projections "blade").coreCount;
      expected = 19;
    };

    # TEETH: a corrupted core value ⇒ gate FALSE and the two digests DIFFER (not vacuously equal).
    test-gate-teeth-corrupt-fails = {
      expr = teethGate.gate;
      expected = false;
    };
    test-gate-teeth-digests-differ = {
      expr = teethGate.candidateDigest != teethGate.realDigest;
      expected = true;
    };
  };

  # ══ compareCounters — the two-tier policy (exact same-build / band cross-build) ═
  flake.tests.compare-counters = {
    # exact: identical ⇒ overall pass; a single off-by-one ⇒ fail (same-build has no tolerance).
    test-exact-identical-passes = {
      expr = exactPass.pass;
      expected = true;
    };
    test-exact-off-by-one-fails = {
      expr = exactOffByOne.pass;
      expected = false;
    };

    # band: the −8-on-20M build drift PASSES (relative delta strictly between 0 and the band).
    test-band-tiny-drift-passes = {
      expr = bandTinyDrift.pass;
      expected = true;
    };
    test-band-tiny-drift-delta-within-band = {
      expr =
        let
          d = (builtins.head bandTinyDrift.verdicts).delta;
        in
        d > 0.0 && d < 0.001;
      expected = true;
    };
    # band: a real 2× regression FAILS (relative delta 1.0 ≫ 0.001).
    test-band-regression-fails = {
      expr = bandRegression.pass;
      expected = false;
    };

    # MIXED per-counter verdicts: `a` within band (pass), `b` doubled (fail) ⇒ overall fail, and the
    # per-counter split is exactly [ a=pass, b=fail ] (verdicts are sorted by counter name).
    test-mixed-overall-fails = {
      expr = bandMixed.pass;
      expected = false;
    };
    test-mixed-per-counter-split = {
      expr = builtins.map (v: {
        inherit (v) counter pass;
      }) bandMixed.verdicts;
      expected = [
        {
          counter = "a";
          pass = true;
        }
        {
          counter = "b";
          pass = false;
        }
      ];
    };
  };
}
