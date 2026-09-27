# THE invariantUnder DOOR CHECK FIRES AT APPLICATION, NOT ONLY BEHIND A LATER FIELD READ
# (den-hoag-7gp66 P1 lazy-doors fix).
#
# `invariantUnder` is a RECORD door (R5): all three fields required, no `checkOptions` closing. Its
# return was a bare attrset literal — `{ invariant = divergingKeys == [ ]; inherit divergingKeys; }`
# — and `divergingKeys` never touches `checked.projection` (unused by this door's own body), so
# neither field of the return forced `checked` to WHNF. `checkRequired` therefore sat unread until a
# caller forced `.invariant` or `.divergingKeys`, admitting a bad record at the door's own
# application — the shape of a defensive `builtins.seq (door args) rest` a caller writes to gate on
# validity before touching any output. This file pins that with a narrower predicate than a field
# read could ever exercise: `seq` alone, to WHNF of the door's own return, reading NO field at all.
#
# MEASURED (den-hoag-7gp66 P1 strictness sweep, gen-memo eed0685's defect class): both the
# missing-required and non-attrset arms answered rather than refused at application. Fixed by
# threading `builtins.seq checked` through the return — the same idiom `applyCoreFixed` (this
# library, same file) and gen-settings' door fix (0474486) already use.
{ genClass, ... }:
let
  inherit (genClass) invariantUnder;

  refusesAtApplication = e: !(builtins.tryEval (builtins.seq e null)).success;
  answersAtApplication = e: (builtins.tryEval (builtins.seq e null)).success;
in
{
  flake.tests.door-application-strictness = {
    # ★ LIVE CONTROL FOR THE WHOLE SUITE, first: `tryEval`+`seq` catches an ordinary throw, and a
    # non-throwing value answers. Without this, every `refusesAtApplication` cell below is equally
    # consistent with a predicate that reads `false` no matter what it is handed.
    test-control-tryeval-seq-catches-an-ordinary-throw = {
      expr = refusesAtApplication (throw "control probe, not this suite's subject");
      expected = true;
    };
    test-control-tryeval-seq-answers-a-non-throwing-value = {
      expr = answersAtApplication 1;
      expected = true;
    };

    # invariantUnder — FIXED: was a bare attrset literal; now `builtins.seq checked { … }`.
    test-invariantunder-missing-required-field-refused-at-application = {
      expr = refusesAtApplication (invariantUnder { });
      expected = true;
    };
    test-invariantunder-non-attrset-refused-at-application = {
      expr = refusesAtApplication (invariantUnder "zzq_p1_str");
      expected = true;
    };
  };
}
