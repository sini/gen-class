# gen-class — lib/partition.nix : `mkClasses` grouping — "key narrows, the gate decides" (spec §2.2).
#
# DISCIPLINE (spec §2.2, verbatim requirements — these are the API contract, not advice).
#   KEYS NARROW, THEY DO NOT AUTHORISE. `keyOf` supplies the partition key (classKey semantics:
#   sorted include-sets / sanitised resolved-aspects). Its caveat is INHERITED verbatim: function
#   values sentinel-erase under such a key, so a key can only NARROW the candidate set of members that
#   MIGHT share — it never authorises reuse. THE GATE DECIDES: only gate.nix byte-equality is
#   authority that a projection is actually shared.
#   RE-PARTITION ON STRUCTURAL CHANGE: a node whose key changed is regrouped (partition is recomputed,
#   never patched). MEMBER CONFIG CHANGE => UNCONDITIONAL RE-GATE: same key, changed projection ⇒ the
#   core oracle (apply.nix) and byte gate (gate.nix) MUST re-run; partition caches no share decision.
#   These restate the fleet-spec re-validation triggers as this lib's contract.
#
# SINGLETONS pass through as 1-member classes (documented rationale): a 1-member class costs nothing
# to carry and keeps every downstream shape uniform — apply over a singleton core is identity and the
# gate is trivially true, so no special case is warranted anywhere in the pipeline.
#
# DETERMINISM. Members are SORTED here — partition OWNS member order; mkClass stores members as-given
# (banked contract, so neither `attrNames` nor `groupBy` ordering is load-bearing). Class order =
# `attrNames grouped` = key-sorted. Archetype is left to mkClass's deterministic default (head of
# sorted members). A `nodes` attrset is key-ordered, so any permuted construction yields a
# byte-identical class list.
#
# NAMING FENCE (spec §0): the public surface is FLAT and never uses `inject`; this file exports
# exactly `mkClasses`.
{ prelude, contract }:
let
  inherit (prelude)
    attrNames
    map
    sort
    ;
  inherit (builtins)
    groupBy
    lessThan
    ;
  inherit (contract) mkClass;

  # mkClasses { nodes; keyOf; } -> [Class]. Group node names by their key, one mkClass record per
  # group, classes key-sorted, members sorted. `keyOf name node` MUST return a string (groupBy's
  # contract — classKey semantics).
  mkClasses =
    { nodes, keyOf }:
    let
      grouped = groupBy (name: keyOf name nodes.${name}) (attrNames nodes);
    in
    map (
      key:
      mkClass {
        inherit key;
        members = sort lessThan grouped.${key};
      }
    ) (attrNames grouped);
in
{
  inherit mkClasses;
}
