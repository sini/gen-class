# Standalone (non-flake) entry. Flake consumers should use the `.lib` output.
#
# gen-class is a function of `prelude` (required — gen-prelude, the pure utility base) and `merge`
# (OPTIONAL — the injected gen-merge kernel for the tier-2 fixed-input path; every tier-1 export
# works with `merge = null`). The default fetches the flake-locked gen-prelude rev (content-addressed
# via narHash, so the plain-import path stays pure and in lockstep with the flake output; per the gen
# root-file convention). Pass either explicitly to override (e.g. a local gen-prelude checkout, or a
# gen-merge value to enable tier 2).
{
  lock ? builtins.fromJSON (builtins.readFile ./flake.lock),
  fetch ?
    name:
    builtins.fetchTree (
      let
        node = lock.nodes.${lock.nodes.root.inputs.${name}}.locked;
      in
      node
    ),
  prelude ? import "${fetch "gen-prelude"}/lib",
  merge ? null,
}:
import ./lib { inherit prelude merge; }
