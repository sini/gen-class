# Apply-fixed suite (plan Task 7): `applyCoreFixed` — the TIER-2 path driving the injected gen-merge
# fixed-input kernel (spec §2.5). Four groups:
#   fixed-skip   — SOLE-def core loc: applyCoreFixed == plain full-merge byte-identically (gateCore
#                  green) AND the spine skip DETERMINISTICALLY fires (throwing-merge proof, adapted from
#                  gen-merge ci/tests/core-kernel.nix `soleCoreThrow`).
#   fixed-fall   — a member also DEFINES the core loc ⇒ kernel falls through to the full merge (byte-
#                  identical, gateCore green); no spine skip (documented).
#   fixed-teeth  — a WRONG core is applied verbatim and gateCore against the REAL member is RED.
#   fixed-guard  — the tier-1 lib (merge = null) throws a clear gen-class error from applyCoreFixed.
#
# `genClassWithMerge` = the lib wired with the injected kernel; `genClass` = the merge=null lib (guard);
# `genMerge` = the raw kernel, used ci-side to build the throwing-merge proof + plain-values references.
{
  lib,
  genClass,
  genClassWithMerge,
  genMerge,
  ...
}:
let
  inherit (genClassWithMerge)
    mkClass
    mkCore
    mkCoreRecord
    applyCoreFixed
    gateCore
    ;
  corpus = import ./_fixtures/corpus.nix { inherit lib; };
  inherit (builtins) toJSON;

  # Throw-probe (contract.nix convention): force `e` fully, report whether evaluation FAILED.
  didThrow = e: !(builtins.tryEval (builtins.deepSeq e null)).success;
  succeeds = e: (builtins.tryEval (builtins.deepSeq e null)).success;

  # ── the corpus core: 6 agents, projection "agent.opts", the 40-key byte-identical shared subtree ──
  agentClass = mkClass {
    key = "agent";
    members = corpus.agents.members;
  };
  agentCore = mkCore {
    class = agentClass;
    inherit (corpus.agents) projection projections;
  };

  # projection helpers (the projection is dotted: "agent.opts" -> [ "agent" "opts" ]).
  projPath = [
    "agent"
    "opts"
  ];
  setPath =
    path: v: if path == [ ] then v else { ${builtins.head path} = setPath (builtins.tail path) v; };
  getProj = cfg: lib.getAttrFromPath projPath cfg;

  # The full-merge REFERENCE twin of applyCoreFixed's internal coreModule: the SAME shape (a type-less
  # projection-option leaf) but the marker REPLACED by the plain `values`. Running it through the engine
  # (coreShortCircuit off) is the byte oracle for the with-core path.
  plainCoreModule = core: {
    options = setPath projPath (genMerge.mkOption { });
    config = setPath projPath core.values;
  };
  refConfig = modules: (genMerge.evalModuleTree { inherit modules; }).config;

  # ══ fixed-skip ═════════════════════════════════════════════════════════════
  # A member contributing an AXIS loc (a different option) — the contract's normal shape (members carry
  # axis, coreModule carries the sole core-projection def).
  axisMember = {
    options.axisKey = genMerge.mkOption { type = genMerge.anything; };
    config.axisKey = "member-axis";
  };
  skipFixed =
    (applyCoreFixed {
      core = agentCore;
      modules = [ axisMember ];
    }).config;
  skipRef = refConfig [
    axisMember
    (plainCoreModule agentCore)
  ];
  skipGate = gateCore {
    core = agentCore;
    candidate = getProj skipFixed;
    real = getProj skipRef;
  };

  # DETERMINISTIC firing proof (throwing merge). boomType's `.merge` throws; a MEMBER declares the
  # projection option WITH it (no def). Through applyCoreFixed the type-less coreModule lets boomType
  # SURVIVE the option field-union, while the marker stays the sole def ⇒ soleCore skips `.merge`
  # ⇒ core.values, no throw. The same option + a sole marker def with the kernel OFF runs `.merge` ⇒ throws.
  boomType = genMerge.mkOptionType {
    name = "boom";
    merge = loc: _defs: throw "gen-class-test: SPINE-RAN at ${genMerge.showOption loc}";
  };
  boomDecl = {
    options.agent.opts = genMerge.mkOption { type = boomType; };
  };
  skipThroughBoom =
    (applyCoreFixed {
      core = agentCore;
      modules = [ boomDecl ];
    }).config;
  offRunsSpine =
    didThrow
      (genMerge.evalModuleTree {
        coreShortCircuit = false;
        modules = [
          boomDecl
          { config.agent.opts = genMerge.mkCoreValue { inherit (agentCore) digest values; }; }
        ];
      }).config;

  # ══ fixed-fall — a member ALSO defines the core loc (with a real anything type) ═════════════════════
  ftMember = {
    options.agent.opts = genMerge.mkOption { type = genMerge.anything; };
    config.agent.opts = {
      extraAxis = "axis-under-projection";
    };
  };
  ftFixed =
    (applyCoreFixed {
      core = agentCore;
      modules = [ ftMember ];
    }).config;
  ftRef = refConfig [
    ftMember
    (plainCoreModule agentCore)
  ];
  ftGate = gateCore {
    core = agentCore;
    candidate = getProj ftFixed;
    real = getProj ftRef;
  };

  # ══ fixed-teeth — a WRONG core (same keys, one tampered value) ══════════════════════════════════════
  wrongCore = mkCoreRecord {
    class = agentClass;
    projection = "agent.opts";
    sharedKeys = agentCore.sharedKeys;
    values = agentCore.values // {
      "opt00" = "TAMPERED";
    };
  };
  wrongFixed =
    (applyCoreFixed {
      core = wrongCore;
      modules = [ ];
    }).config;
  realConfig = refConfig [ (plainCoreModule agentCore) ];
  wrongGate = gateCore {
    core = wrongCore;
    candidate = getProj wrongFixed;
    real = getProj realConfig;
  };
in
{
  # ══ fixed-skip — byte identity + deterministic firing proof ════════════════
  flake.tests.fixed-skip = {
    # applyCoreFixed's projection output is byte-identical to the full-merge reference (gate authority).
    test-skip-gate-green = {
      expr = skipGate.gate;
      expected = true;
    };
    # ...and the WHOLE config (core projection + member axis) matches byte-for-byte.
    test-skip-whole-config-byte-identical = {
      expr = toJSON skipFixed == toJSON skipRef;
      expected = true;
    };
    # the projection loc reconstructs EXACTLY core.values (the short-circuit returned `values` verbatim).
    test-skip-returns-core-values = {
      expr = getProj skipFixed == agentCore.values;
      expected = true;
    };
    # DETERMINISTIC firing: through applyCoreFixed the throwing `.merge` is SKIPPED (evaluates, no throw)...
    test-skip-fires-through-boom = {
      expr = succeeds skipThroughBoom && getProj skipThroughBoom == agentCore.values;
      expected = true;
    };
    # ...whereas the SAME option + sole marker def with the kernel OFF runs the throwing spine.
    test-off-runs-throwing-spine = {
      expr = offRunsSpine;
      expected = true;
    };
  };

  # ══ fixed-fall — member also defines the core loc ⇒ byte-identical fall-through, no skip ════
  flake.tests.fixed-fall = {
    test-fall-through-gate-green = {
      expr = ftGate.gate;
      expected = true;
    };
    test-fall-through-byte-identical = {
      expr = toJSON ftFixed == toJSON ftRef;
      expected = true;
    };
    # the fall-through actually MERGED (member axis key survives beside the core values) — not skipped.
    test-fall-through-merges-axis = {
      expr =
        (getProj ftFixed).extraAxis == "axis-under-projection"
        && (getProj ftFixed).opt00 == agentCore.values.opt00;
      expected = true;
    };
  };

  # ══ fixed-teeth — a WRONG core is applied verbatim; gateCore against the real member is RED ══
  flake.tests.fixed-teeth = {
    # the short-circuit returned the tampered value verbatim (no merge could have produced it).
    test-wrong-core-applied-verbatim = {
      expr = (getProj wrongFixed).opt00;
      expected = "TAMPERED";
    };
    # the byte gate CATCHES the divergence (else the parity claim is vacuous).
    test-wrong-core-gate-red = {
      expr = wrongGate.gate;
      expected = false;
    };
    test-wrong-core-digests-differ = {
      expr = wrongGate.candidateDigest == wrongGate.realDigest;
      expected = false;
    };
  };

  # ══ fixed-guard — tier-1 lib (merge = null) throws a clear gen-class error ══
  flake.tests.fixed-guard = {
    test-merge-null-throws = {
      expr = didThrow (
        genClass.applyCoreFixed {
          core = agentCore;
          modules = [ ];
        }
      );
      expected = true;
    };
  };
}
