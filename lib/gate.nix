# gen-class — lib/gate.nix : the hard-fail byte gate (`gateCore`) + the PURE half of the two-tier
# STOP-on-diff counter policy (`compareCounters`), spec §2.4.
#
# THEORY. Gate-B / WHNF spine bound: a class-share claim is only ever authorised by BYTE equality
# between the core-applied CANDIDATE and the REAL member — never by the partition key (keys narrow,
# the gate decides, partition.nix). The gate is a sha256 over canonical toJSON; the CANONICALITY
# CONTRACT is mkCoreRecord's verbatim (builtins.toJSON emits attrset keys sorted ⇒ the digest is
# insertion-order-independent and equal iff the values are byte-equal). This API exposes NO gate-free
# reuse path (spec §7): there is no Merkle-id shortcut and no `...OrThrow` variant — `gateCore` always
# returns the decision as a RECORD, and the consumer / ci driver hard-fails on `gate == false`.
#
# TWO-TIER COUNTER POLICY (the pure half only; the harness — ×N reps, never-average, loud setup-eval
# failures — is lifted ci-side from the 7b driver). Documented BY REFERENCE, thresholds caller-
# supplied (hola ci/bench/MEASUREMENT.md §"Counter determinism"):
#   - EXACT (same-build): the deterministic counter set (nrPrimOpCalls / nrFunctionCalls /
#     nrOpUpdateValuesCopied + both digests) is bit-reproducible for the SAME evaluator BUILD, so an
#     equality gate is same-build-only.
#   - BAND (cross-build): a version STRING does not identify a build — Determinate vs CppNix both print
#     nix 2.34.7 yet differ by −8 on nrPrimOpCalls (~4e-7 relative). A relative band (±0.1% default)
#     swallows that build noise but not a real O(k²) blowup.
#   - gc.totalBytes / cpuTime are recorded-only and NEVER gated — the caller simply omits them from
#     `expected` / `actual`; this comparator gates exactly the counters it is handed.
#
# NAMING FENCE (spec §0): the public surface never uses `inject`; verbs are `gateCore` /
# `compareCounters`. The API stays FLAT (ci/tests/fence.nix walks top-level names).
{ prelude }:
let
  inherit (prelude)
    all
    attrNames
    isAttrs
    length
    map
    ;
  inherit (builtins)
    hashString
    toJSON
    ;

  isCore = x: isAttrs x && (x._type or null) == "gen-class/core";

  # Canonical byte digest — sha256 of sorted-key toJSON (mkCoreRecord's canonicality contract).
  digestOf = v: hashString "sha256" (toJSON v);

  # gateCore { core; candidate; real; } -> { gate; candidateDigest; realDigest; coreCount; }. The
  # hard-fail byte gate: `gate` is true iff the core-applied CANDIDATE is byte-identical to the REAL
  # member. coreCount = length core.sharedKeys — evidence of how many keys the core CLAIMED to share
  # (informational; the gate, not the count, is authority). RECORD ONLY, never throws on the outcome.
  gateCore =
    {
      core,
      candidate,
      real,
    }:
    if !isCore core then
      throw "gen-class: gateCore: core must be a gen-class/core record"
    else
      let
        candidateDigest = digestOf candidate;
        realDigest = digestOf real;
      in
      {
        gate = candidateDigest == realDigest;
        inherit candidateDigest realDigest;
        coreCount = length core.sharedKeys;
      };

  # Relative delta = |actual − expected| / max(|expected|, 1). The max guard keeps a ZERO baseline
  # well-defined (any nonzero drift from zero exceeds any sub-unit band) without a magic sentinel;
  # for a real counter (|expected| ≥ 1) it is the plain relative delta. `1.0 *` forces FLOAT division
  # (Nix `/` on two ints truncates — 8 / 20000000 would be 0, not 4e-7).
  absNum = x: if x < 0 then -x else x;
  relDelta =
    exp: act:
    let
      d = absNum (act - exp);
      denom = absNum exp;
    in
    1.0 * d / (if denom < 1 then 1 else denom);

  # compareCounters { expected; actual; mode; } -> { pass; verdicts; }. `mode` is "exact" (same-build
  # equality) or { band = <float>; } (cross-build relative tolerance). Per-counter verdict records
  # { counter; expected; actual; delta; pass; } over the (identical) counter sets, sorted by name;
  # overall `pass` = all verdicts pass. `delta` is the relative delta (informational in exact mode).
  compareCounters =
    {
      expected,
      actual,
      mode,
    }:
    let
      isExact = mode == "exact";
      isBand = isAttrs mode && mode ? band;
      band = if isBand then mode.band else null;
      verdictFor =
        c:
        let
          exp = expected.${c};
          act = actual.${c};
          d = relDelta exp act;
        in
        {
          counter = c;
          expected = exp;
          actual = act;
          delta = d;
          pass = if isExact then act == exp else d <= band;
        };
      verdicts = map verdictFor (attrNames expected);
    in
    if !isExact && !isBand then
      throw "gen-class: compareCounters: mode must be \"exact\" or { band = <float>; } (got ${toJSON mode})"
    else if attrNames expected != attrNames actual then
      throw "gen-class: compareCounters: expected and actual must share one counter set (${toJSON (attrNames expected)} vs ${toJSON (attrNames actual)})"
    else
      {
        inherit verdicts;
        pass = all (v: v.pass) verdicts;
      };
in
{
  inherit gateCore compareCounters;
}
