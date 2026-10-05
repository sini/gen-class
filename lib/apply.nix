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
#
# TIER-2 (`applyCoreFixed`) drives the injected gen-merge fixed-input kernel (spec §2.5): it hands the
# engine a pre-computed core value and the engine SKIPS the discharge/fold/verify spine for that loc
# (`evalModuleTree { coreShortCircuit = true; }`). merge-independent tier-1 stays usable with
# merge = null; applyCoreFixed throws a clear error there.
{
  prelude,
  contract,
  merge, # tier-2 gen-merge kernel; null ⇒ tier-1 only (applyCoreFixed unavailable, throws clearly).
}:
let
  inherit (prelude)
    all
    attrNames
    attrValues
    filter
    isAttrs
    isList
    listToAttrs
    map
    mapAttrs
    nameValuePair
    setAttrByPath
    sort
    ;
  inherit (builtins)
    isString
    lessThan
    removeAttrs
    split
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

  # Whether `toJSON v` returns rather than aborts: a function anywhere toJSON walks is an evaluator
  # error that escapes `tryEval`. Mirrors toJSON's own walk — `__toString` first, then `outPath` —
  # so its function test is the BUILTIN one: a functor is an attrset to `toJSON`, and one carrying
  # `__toString` serialises (gen-prelude's `isFunction` is nixpkgs' functor-aware reader).
  serialisable =
    v:
    if builtins.isFunction v then
      false
    else if isAttrs v then
      v ? __toString || (if v ? outPath then serialisable v.outPath else all serialisable (attrValues v))
    else if isList v then
      all serialisable v
    else
      true;

  # oracle verb { class; projections; } -> { archProj; agrees : key -> bool; } — THE ORACLE, shared by
  # mkCore (keeps the archetype keys `agrees` holds for) and invariantUnder (reports those it fails
  # for): k is PRESENT in every member and toJSON-equal to the archetype's value. The two caller-input
  # mistakes it would otherwise abort on outside `tryEval` are refused as throws, in mkClass's
  # phrasing: projections not covering class.members, and a compared value toJSON cannot serialise.
  oracle =
    verb:
    { class, projections }:
    let
      inherit (class) members archetype;
      missing = filter (m: !(projections ? ${m})) members;
      json =
        m: k:
        let
          v = projections.${m}.${k};
        in
        if serialisable v then
          toJSON v
        else
          throw "gen-class: ${verb}: projections.${m}.${k} must be toJSON-serialisable (it holds a function)";
    in
    if missing != [ ] then
      throw "gen-class: ${verb}: projections must cover class.members (missing ${toJSON missing})"
    else
      {
        archProj = projections.${archetype};
        agrees = k: all (m: (projections.${m} ? ${k}) && json archetype k == json m k) members;
      };

  # mkCore { class; projection; projections; } -> Core. projections = memberName -> attrs (the already-
  # extracted projection subtree per member; must cover class.members). The presence-guarded byte-
  # identical intersection, sorted; values = the archetype's projection restricted to sharedKeys.
  # ONE KEYED RECORD, OPEN (den-hoag-7gp66 P2, rule 5 and the keyed-record ruling): `projections` is
  # the subject, but `class` and `projection` are two configuration operands with no natural order,
  # so the three stay one record whose fields are named at the call site. The record is a
  # `prelude.door`: a missing field is refused by name and catchably at the application; an extra
  # field is admitted (R5).
  mkCore = prelude.door {
    name = "gen-class.mkCore";
    required = [
      "class"
      "projection"
      "projections"
    ];
    open = true;
  } mkCoreCore;
  mkCoreCore =
    {
      class,
      projection,
      projections,
      ...
    }:
    let
      inherit (oracle "mkCore" { inherit class projections; }) archProj agrees;
      sharedKeys = sort lessThan (filter agrees (attrNames archProj));
    in
    mkCoreRecord {
      inherit class projection sharedKeys;
      # attrNames of a listToAttrs come out sorted, and sharedKeys is sorted ⇒ mkCoreRecord's
      # `attrNames values == sharedKeys` validation holds by construction.
      values = listToAttrs (map (k: nameValuePair k archProj.${k}) sharedKeys);
    };

  # applyCoreMerge core memberProjection -> attrs — 7b's `shareClassProjection`, productized:
  # `core.values // removeAttrs memberProjection core.sharedKeys`. The CORE OWNS sharedKeys: removeAttrs
  # strips the member's copies, core.values supplies them, so a member value at a shared key is
  # OVERRIDDEN by the core value (the axis-disjointness discipline manifesting — axis keys ∩
  # sharedKeys = ∅ is the caller's contract; overlap is harmless because the core wins).
  # PROJECTION-ONLY LIMIT (spec §2.3): this returns the projection SUBTREE, not a deployable toplevel —
  # toplevel recovery FROM this spine-skipped path is tier-3/den-hoag (fenced), a DIFFERENT capability
  # from applyCoreExtend (which pays the full per-member re-eval to legitimately yield a toplevel).
  # POSITIONAL (den-hoag-7gp66 P2, rule 4): the core is configuration, first; the member projection it
  # is applied to is the subject, last.
  applyCoreMerge =
    core: memberProjection: core.values // removeAttrs memberProjection core.sharedKeys;

  # applyCoreExtend core extend -> artifact — the variant over a caller-supplied `extend` (the
  # A1 1.89× path). Places the core values, force-wrapped PER KEY, under the projection path; per-key
  # (not whole-subtree) so member axis keys under the same subtree survive. SPINE-TAX CAVEAT (spec
  # §2.3): the member re-runs evalModules — this path DOES yield a deployable toplevel, legitimately, by
  # paying the full per-member re-eval; the fixed-input spine skip is applyCoreFixed (tier 2, Task 7).
  # `extend` is the hosted module system's extension function, supplied by the caller; gen-class names
  # none (ADR-0027: the evaluator's location is the caller's). For a nixpkgs `evalModules` result the
  # caller hands its `extendModules` unwrapped, and this construct calls it with `{ modules }`. The
  # `mkForced` record is hand-built in the `_type = "override"` encoding gen-merge also reads, so the
  # core module is engine-neutral. Totality of `extend`: a non-function is refused by name, catchably;
  # a functor is admitted; its return is opaque; a pattern-formal `extend` lacking `modules` is Nix's
  # own abort.
  # POSITIONAL (den-hoag-7gp66 P2, rule 4): the core is configuration, first; the member's `extend`
  # it is applied through is the subject, last.
  applyCoreExtend =
    core: extend:
    if !(builtins.isFunction extend || (builtins.isAttrs extend && extend ? __functor)) then
      throw "gen-class.applyCoreExtend: `extend` must be a function taking { modules } (e.g. an evaluation result's `extendModules`), not a ${builtins.typeOf extend}"
    else
      extend {
        modules = [
          { config = setAttrByPath (splitOnDots core.projection) (mapAttrs (_: v: mkForced v) core.values); }
        ];
      };

  # invariantUnder { projection; projections; class; } -> { invariant; divergingKeys; } — the class-
  # invariance probe (7b step 4 lifted). divergingKeys = the archetype keys that are NOT byte-identical
  # across all members (same presence+value guard as the oracle, complemented); invariant = none diverge.
  # Guards leaf projections one might naively assume shared (the system.path lesson).
  # ONE KEYED RECORD, OPEN (den-hoag-7gp66 P2, as `mkCore` above): `class` and `projection` are two
  # configuration operands with no natural order beside the `projections` subject. The record is a
  # `prelude.door`, whose check is forced at the application itself (P2 premise 5), so a bad record is
  # refused at the door's own WHNF even though this body's return is an attrset literal.
  invariantUnder =
    prelude.door
      {
        name = "gen-class.invariantUnder";
        required = [
          "class"
          "projection"
          "projections"
        ];
        open = true;
      }
      (
        { class, projections, ... }:
        let
          inherit (oracle "invariantUnder" { inherit class projections; }) archProj agrees;
          divergingKeys = sort lessThan (filter (k: !(agrees k)) (attrNames archProj));
        in
        {
          invariant = divergingKeys == [ ];
          inherit divergingKeys;
        }
      );

  # applyCoreFixed { engineArgs ? {}; } core modules -> evalModuleTree result — the TIER-2 path (spec
  # §2.5). Runs the injected gen-merge kernel with `coreShortCircuit = true` and a `coreModule` that
  # supplies the core's projection value as a pre-merged `mkCoreValue` marker: where that marker is the
  # SOLE def at its loc, the engine returns `core.values` directly, skipping the discharge/fold/verify
  # spine (byte-identical to the full merge by contract — a WRONG core surfaces at gateCore, not here).
  #
  # FIRING-CONDITION CONTRACT (spec §2.5; the kernel's own firing scope, lib/modules.nix). The skip
  # fires ONLY where the core def is the SOLE def at a DECLARED-OPTION LEAF. This fn upholds it by:
  #   • placing the marker at the WHOLE projection option leaf — never at sub-keys of an attrsOf (those
  #     ride the plain per-element fold and never short-circuit);
  #   • declaring that option with NO `default` (a default appends a second def, demoting sole-core to
  #     fall-through — still byte-identical, but no spine skip);
  #   • declaring it TYPE-LESS (`merge.mkOption { }`): the core projection loc is coreModule's to define,
  #     and a member module that legitimately declares the option's real merge-type wins the option
  #     field-union (coreModule carries no `.type` to clobber it) while the marker stays the sole def.
  # A member module that ALSO *defines* (not just declares) the core loc is SAFE — the kernel falls
  # through to the full merge (byte-identical) — but forfeits the spine skip.
  # OPTIONS FIRST, then `core` and `modules` (den-hoag-7gp66 P2, rules 2 and 4): the one optional
  # field leaves for a closed options set, a `prelude.door` refused by name and catchably at
  # `applyCoreFixed opts`'s own WHNF, ahead of the merge==null guard below. The core is configuration;
  # the module list it is evaluated with is the subject, last.
  applyCoreFixed =
    prelude.door
      {
        name = "gen-class.applyCoreFixed";
        optional = [ "engineArgs" ];
      }
      (
        o: core: modules:
        let
          engineArgs = o.engineArgs or { };
        in
        if merge == null then
          throw "gen-class: applyCoreFixed: the tier-2 fixed-input path requires the injected gen-merge kernel, but `merge` is null. Import gen-class with `merge = <gen-merge>.lib` (README §tier-2); every tier-1 verb works without it."
        else
          let
            path = splitOnDots core.projection;
            coreModule = {
              options = setAttrByPath path (merge.mkOption { });
              config = setAttrByPath path (merge.mkCoreValue core.digest core.values);
            };
          in
          merge.evalModuleTree (engineArgs // { coreShortCircuit = true; }) (modules ++ [ coreModule ])
      );
in
{
  inherit
    mkCore
    applyCoreMerge
    applyCoreExtend
    invariantUnder
    applyCoreFixed
    ;
}
