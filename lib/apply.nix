# gen-class — lib/apply.nix : the tier-1 core-application mechanisms (spec §2.3), lifted from the 7b
# driver (hola ci/bench/class-share-realization.sh) and generalized to N members.
#
# THE ORACLE (mkCore). sharedKeys = the byte-identical intersection ACROSS ALL members, PRESENCE-
# GUARDED: a key counts only if it is PRESENT in every member (`?`-term) AND its value is toJSON-equal
# to the archetype's (7b's `toJSON eq`). Computed per class per projection — NEVER assumed: the
# system.path lesson is that a leaf one might naively call shared can silently be host-specific, so the
# gate always recomputes. Empty intersection ⇒ a valid Core with sharedKeys = [] and apply = identity
# (documented, not an error). The heterogeneous corpus exercises the presence guard (a blade-only key).
#
# NAMING FENCE (spec §0): the public surface never uses `inject`; verbs are mkCore / applyCore* only.
# `applyCoreFixed` (tier 2, via the injected `merge` kernel) lands in Task 7; `merge` is threaded but
# unused here (tier-1 works with merge = null).
{
  prelude,
  contract,
  merge, # tier-2 kernel (Task 7); tier-1 mechanisms below are merge-independent.
}:
let
  inherit (prelude)
    all
    attrNames
    filter
    head
    listToAttrs
    map
    mapAttrs
    nameValuePair
    sort
    ;
  inherit (builtins)
    isString
    lessThan
    removeAttrs
    split
    tail
    toJSON
    ;
  inherit (contract) mkCoreRecord;

  # Forced override record — byte-compatible with nixpkgs `mkForce` (priority 50). Hand-built so lib/
  # carries NO nixpkgs dependency (ci/tests/purity.nix enforces the fence); the SAME convention
  # gen-merge's priority pass vendors (`mkForce = mkOverride 50`, priority.nix). The nixpkgs module
  # system dispatches on `_type == "override"` + `priority`, so this record wins over a bare def (100).
  mkForced = v: {
    _type = "override";
    priority = 50;
    content = v;
  };

  # A dotted projection "systemd.units" -> [ "systemd" "units" ] via builtins.split (NO nixpkgs
  # splitString); the string fragments survive the filter, the empty match-group lists are dropped.
  splitOnDots = s: filter isString (split "\\." s);
  setAttrByPath =
    path: value:
    if path == [ ] then
      value
    else
      {
        ${head path} = setAttrByPath (tail path) value;
      };

  # mkCore { class; projection; projections; } -> Core. projections = memberName -> attrs (the already-
  # extracted projection subtree per member; must cover class.members). The presence-guarded byte-
  # identical intersection, sorted; values = the archetype's projection restricted to sharedKeys.
  mkCore =
    {
      class,
      projection,
      projections,
    }:
    let
      inherit (class) members archetype;
      archProj = projections.${archetype};
      sharedKeys = sort lessThan (
        filter (
          k:
          all (m: (projections.${m} ? ${k}) && toJSON archProj.${k} == toJSON projections.${m}.${k}) members
        ) (attrNames archProj)
      );
    in
    mkCoreRecord {
      inherit class projection sharedKeys;
      # attrNames of a listToAttrs come out sorted, and sharedKeys is sorted ⇒ mkCoreRecord's
      # `attrNames values == sharedKeys` validation holds by construction.
      values = listToAttrs (map (k: nameValuePair k archProj.${k}) sharedKeys);
    };

  # applyCoreMerge { core; memberProjection; } -> attrs — 7b's `shareClassProjection`, productized:
  # `core.values // removeAttrs memberProjection core.sharedKeys`. The CORE OWNS sharedKeys: removeAttrs
  # strips the member's copies, core.values supplies them, so a member value at a shared key is
  # OVERRIDDEN by the core value (the axis-disjointness discipline manifesting — axis keys ∩
  # sharedKeys = ∅ is the caller's contract; overlap is harmless because the core wins).
  # PROJECTION-ONLY LIMIT (spec §2.3): this returns the projection SUBTREE, not a deployable toplevel —
  # toplevel recovery FROM this spine-skipped path is tier-3/den-hoag (fenced), a DIFFERENT capability
  # from applyCoreExtend (which pays the full per-member re-eval to legitimately yield a toplevel).
  applyCoreMerge =
    { core, memberProjection }: core.values // removeAttrs memberProjection core.sharedKeys;

  # applyCoreExtend { core; system; } -> system — the extendModules variant for nixpkgs terminals (the
  # A1 1.89× path). Places the core values, force-wrapped PER KEY, under the projection path; per-key
  # (not whole-subtree) so member axis keys under the same subtree survive. SPINE-TAX CAVEAT (spec
  # §2.3): the member re-runs evalModules — this path DOES yield a deployable toplevel, legitimately, by
  # paying the full per-member re-eval; the fixed-input spine skip is applyCoreFixed (tier 2, Task 7).
  applyCoreExtend =
    { core, system }:
    system.extendModules {
      modules = [
        { config = setAttrByPath (splitOnDots core.projection) (mapAttrs (_: v: mkForced v) core.values); }
      ];
    };

  # invariantUnder { projection; projections; class; } -> { invariant; divergingKeys; } — the class-
  # invariance probe (7b step 4 lifted). divergingKeys = the archetype keys that are NOT byte-identical
  # across all members (same presence+value guard as the oracle, complemented); invariant = none diverge.
  # Guards leaf projections one might naively assume shared (the system.path lesson).
  invariantUnder =
    {
      projection,
      projections,
      class,
    }:
    let
      inherit (class) members archetype;
      archProj = projections.${archetype};
      divergingKeys = sort lessThan (
        filter (
          k:
          !(all (
            m: (projections.${m} ? ${k}) && toJSON archProj.${k} == toJSON projections.${m}.${k}
          ) members)
        ) (attrNames archProj)
      );
    in
    {
      invariant = divergingKeys == [ ];
      inherit divergingKeys;
    };
in
{
  inherit
    mkCore
    applyCoreMerge
    applyCoreExtend
    invariantUnder
    ;
}
