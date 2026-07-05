# gen-class ci — the synthetic class corpus, shared by every later suite. import-tree SKIPS paths
# whose name starts with `_`, so this file is a plain DATA fixture (a `{ lib }` -> attrs function),
# never a test module. It takes only `lib` — to synthesise the ~40-key subtree — and holds no
# gen-class dependency. Every designed property below is PINNED by the corpus self-check suite in
# ../partition.nix (the corpus is only trustworthy because those checks recompute its shape).
#
# SHAPES (spec §2.6, lifting the A1 7b heterogeneous-pair experiment):
#   (a) `agents` — a HOMOGENEOUS class: 6 members sharing a ~40-key projection subtree byte-identical
#       across all six, plus a small per-member delta (hostname, rank). The byte-identical
#       intersection the oracle (Task 4) must recover is exactly the 40 shared keys; the deltas differ
#       so they fall out of the core.
#   (b) `hetero` — a HETEROGENEOUS pair blade/cortex, declared ONE class but divergent in config:
#         19 keys shared byte-identical
#       +  4 keys present in BOTH but byte-DIVERGENT (different values)
#       +  2 keys present in blade ONLY, ABSENT from cortex — the PRESENCE guard (banked Task 4
#          requirement: the oracle must AND a `hasAttr` term, not just a value compare).
#       blade carries 25 keys total; 19/25 = 76% shared, mirroring the A1 7b pair (~76%).
#   (c) `leafLike` — a leaf projection (the system.path lesson): INVARIANT across (a) but DIVERGENT
#       across (b). A leaf one might NAIVELY assume shared can silently be host-specific; this feeds
#       Task 4's invariance probe.
{ lib }:
let
  inherit (lib)
    genList
    listToAttrs
    nameValuePair
    sort
    fixedWidthNumber
    ;
  inherit (builtins) lessThan;

  # { name = f name; } over a key list (small local helper; corpus is data, not a lib export).
  attrsFromKeys = f: keys: listToAttrs (map (k: nameValuePair k (f k)) keys);

  # ── (a) homogeneous class: 6 agents ─────────────────────────────────────────
  agentMembers = genList (i: "agent-${toString i}") 6; # agent-0 .. agent-5

  # 40 keys, 2-digit zero-padded so lexical order == numeric order (opt00 .. opt39, already sorted).
  sharedAgentKeys = sort lessThan (genList (i: "opt${fixedWidthNumber 2 i}") 40);
  sharedAgentSubtree = attrsFromKeys (k: "shared-${k}") sharedAgentKeys;

  # per-member projection = the shared subtree + a small delta that DIFFERS per member (so hostname /
  # rank are excluded from the byte-identical core).
  agentProjections = listToAttrs (
    genList (
      i:
      let
        name = "agent-${toString i}";
      in
      nameValuePair name (
        sharedAgentSubtree
        // {
          hostname = name;
          rank = i;
        }
      )
    ) 6
  );

  # leafLike INVARIANT across (a): every agent carries the identical leaf value.
  agentLeaf = {
    path = "/run/current-system/sw";
  };
  agentLeafLike = attrsFromKeys (_: agentLeaf) agentMembers;

  # ── (b) heterogeneous pair: blade / cortex ──────────────────────────────────
  hostSharedKeys = sort lessThan (genList (i: "h${fixedWidthNumber 2 i}") 19); # h00 .. h18
  hostSharedSubtree = attrsFromKeys (k: "host-${k}") hostSharedKeys;

  divergentKeys = [
    "d0"
    "d1"
    "d2"
    "d3"
  ]; # present in BOTH, byte-divergent
  bladeOnlyKeys = [
    "bladeOnly0"
    "bladeOnly1"
  ]; # present in blade ONLY — the presence guard

  bladeProjection =
    hostSharedSubtree
    // attrsFromKeys (k: "blade-${k}") divergentKeys
    // attrsFromKeys (k: "blade-only-${k}") bladeOnlyKeys;
  cortexProjection = hostSharedSubtree // attrsFromKeys (k: "cortex-${k}") divergentKeys;

  hostProjections = {
    blade = bladeProjection;
    cortex = cortexProjection;
  };

  # leafLike DIVERGENT across (b): the system.path lesson — a leaf that is NOT actually shared.
  hostLeafLike = {
    blade = {
      path = "/nix/store/blade";
    };
    cortex = {
      path = "/nix/store/cortex";
    };
  };

  # ── partition fleet: the agents + the hetero pair + one singleton (`lonely`) ─
  nodes = (attrsFromKeys (_: { class = "agent"; }) agentMembers) // {
    blade = {
      class = "host";
    };
    cortex = {
      class = "host";
    };
    lonely = {
      class = "solo";
    };
  };
  keyOf = _name: node: node.class;
in
{
  inherit nodes keyOf;

  agents = {
    key = "agent";
    members = agentMembers;
    projection = "agent.opts";
    sharedKeys = sharedAgentKeys; # the 40-key byte-identical intersection the oracle must recover
    projections = agentProjections;
    leafLike = agentLeafLike;
  };

  hetero = {
    key = "host";
    members = [
      "blade"
      "cortex"
    ];
    archetype = "blade"; # head (sort [ "blade" "cortex" ])
    projection = "host.opts";
    sharedKeys = hostSharedKeys; # 19-key byte-identical intersection (excludes divergent + blade-only)
    divergentKeys = divergentKeys;
    bladeOnlyKeys = bladeOnlyKeys;
    projections = hostProjections;
    leafLike = hostLeafLike;
  };
}
