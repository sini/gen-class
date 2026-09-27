# gen-class — lib/contract.nix : the Class/Core/Axis data contract (spec §2.1).
#
# THEORY. Reynolds defunctionalization (m5 discipline): parametric class behaviour is reduced to
# plain-data records BEFORE anything is keyed, so partition / apply / gate operate on first-order
# values, not closures. These records ARE the seam-as-data.
#
# RECORDS.
#   Class = { _type = "gen-class/class"; key : str; members : [str]; archetype : str; }
#     archetype is the deterministic class representative. DETERMINISTIC RULE (contract, not a
#     heuristic): the default archetype = head (sort lessThan members) — the lexicographically-first
#     member. Partition-order and input-order independent; a caller may pin an explicit archetype
#     (must be a member). members are stored as-given (partition.nix sorts upstream).
#   Core  = { _type = "gen-class/core"; class : Class; projection : str; sharedKeys : [str] (sorted,
#             unique); values : attrs (attrNames == sharedKeys); digest : str; }
#     digest = hashString "sha256" (toJSON values). CANONICALITY CONTRACT: builtins.toJSON emits
#     attrset keys in sorted order, so the digest is insertion-order-independent and stable across
#     evaluations for equal values — the byte gate (gate.nix) and the tier-2 core marker both key on
#     it. values MUST be toJSON-serialisable by construction (the apply oracle keeps only
#     byte-comparable keys, §2.3).
#   Axis  = attrs — per-member delta record, consumer-shaped, NO constructor.
#     DISJOINTNESS DISCIPLINE (enforced by applyCore*, NOT by this schema): at apply time an axis's
#     keys ∩ core.sharedKeys = ∅. The contract states it; apply.nix (Task 4) is where it bites.
#
# DEN-HOAG SEAM (PROPOSAL, tier 3 — out of scope for this lib). Cores are applied inside r2's
# terminal assembly: output-modules → lib.nixosSystem (r2:800-835), via the class `wrap` registration
# props. den-hoag supplies class boundaries from aspect structure (declare-don't-discover). This lib
# DEFINES the contract and ships it as a PROPOSAL; the landing sites + tier-3 obligations live in the
# r2-amendment note (papers gen-specs/gen-class/2026-07-05-r2-seam-amendment-note.md, uncommitted).
#
# NAMING FENCE (spec §0). The public surface never uses the verb `inject` (r2 binds it to a
# resolution effect, policy.provide r2:201). Constructors are mkClass / mkCoreRecord; the API stays
# FLAT (the fence walks top-level names — ci/tests/fence.nix).
{ prelude }:
let
  inherit (prelude)
    attrNames
    checkOptions
    checkRequired
    elem
    head
    isAttrs
    isList
    length
    sort
    unique
    ;
  inherit (builtins)
    hashString
    isString
    lessThan
    toJSON
    typeOf
    ;

  # gen-class/class type guard (mkCoreRecord's class validation; internal — kept off the public API).
  isClass = x: isAttrs x && (x._type or null) == "gen-class/class";

  # gen-prelude's shared door checks (den-hoag-7gp66 P1): a mixed door (key/members required,
  # archetype optional) composes `checkOptions` over `checkRequired` (§v1.2) rather than a native
  # closed formal, so a missing field or an unknown option refuses BY NAME, catchably.
  mkClass =
    args:
    let
      checked = checkOptions "gen-class.mkClass" [
        "key"
        "members"
        "archetype"
      ] (checkRequired "gen-class.mkClass" [ "key" "members" ] args);
      key = checked.key;
      members = checked.members;
      archetype = checked.archetype or null;
    in
    if !isString key then
      throw "gen-class: mkClass: key must be a string (got ${typeOf key})"
    else if !isList members then
      throw "gen-class: mkClass: members must be a list (got ${typeOf members})"
    else if members == [ ] then
      throw "gen-class: mkClass: members must be non-empty"
    else if archetype != null && !(elem archetype members) then
      throw "gen-class: mkClass: archetype ${toJSON archetype} must be one of members ${toJSON members}"
    else
      {
        _type = "gen-class/class";
        inherit key members;
        archetype = if archetype == null then head (sort lessThan members) else archetype;
      };

  # RECORD door (den-hoag-7gp66 P1, R5): all fields required, no `checkOptions` closing — an extra
  # field is admitted and never reported (R5's stated price); a missing one refuses BY NAME.
  mkCoreRecord =
    args:
    let
      checked = checkRequired "gen-class.mkCoreRecord" [
        "class"
        "projection"
        "sharedKeys"
        "values"
      ] args;
      inherit (checked)
        class
        projection
        sharedKeys
        values
        ;
    in
    if !isClass class then
      throw "gen-class: mkCoreRecord: class must be a gen-class/class record"
    else if !isString projection then
      throw "gen-class: mkCoreRecord: projection must be a string (got ${typeOf projection})"
    else if !isList sharedKeys then
      throw "gen-class: mkCoreRecord: sharedKeys must be a list (got ${typeOf sharedKeys})"
    else if sharedKeys != sort lessThan sharedKeys then
      throw "gen-class: mkCoreRecord: sharedKeys must be sorted ${toJSON sharedKeys}"
    else if length (unique sharedKeys) != length sharedKeys then
      throw "gen-class: mkCoreRecord: sharedKeys must be unique ${toJSON sharedKeys}"
    else if attrNames values != sharedKeys then
      throw "gen-class: mkCoreRecord: attrNames values (${toJSON (attrNames values)}) must equal sharedKeys (${toJSON sharedKeys})"
    else
      {
        _type = "gen-class/core";
        inherit
          class
          projection
          sharedKeys
          values
          ;
        digest = hashString "sha256" (toJSON values);
      };
in
{
  inherit mkClass mkCoreRecord;
}
