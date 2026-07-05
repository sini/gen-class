# gen-class public API — class-share mechanism (partition / contract / apply / gate).
# Class layering: consumes gen-prelude; gen-merge is injected ONLY for the tier-2 fixed-input
# path (optional — every tier-1 export works without it).
{
  prelude,
  merge ? null,
}:
let
  contract = import ./contract.nix { inherit prelude; };
  partition = import ./partition.nix { inherit prelude contract; };
  apply = import ./apply.nix { inherit prelude contract merge; };
  gate = import ./gate.nix { inherit prelude; };
in
contract // partition // apply // gate
