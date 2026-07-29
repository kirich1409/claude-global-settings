# Adversarial Review

This file owns the review protocol for translated code: how many reviewers, what independence means
between them, what a valid finding looks like, and when a third opinion is invoked. It does not own
RULEBOOK content or structure — that belongs to `[[rulebook]]` — only how review findings are
produced and routed back to it.

## Two reviewers, separate contexts

Review runs as two independent passes over the same translated unit, each in its own context. Both
receive the same target (the translated file or aspect, the current RULEBOOK, the original) and
produce findings without seeing the other's output first.

Separate contexts is the point, not an efficiency side effect. A single reviewer pass, or two passes
sharing one context, collapses the value this step exists for: the second opinion would anchor on the
first one's framing instead of catching what it missed. Splitting work across contexts only to save
tokens, with the two halves free to see each other's reasoning, is not this protocol — it is a
scheduling optimization wearing the same shape. The value is in an independent perspective on the
same artifact, not in dividing a large artifact into smaller pieces.

The reviewer role is `adversarial-reviewer-role`. Both passes are filled by the same role; nothing in
this protocol distinguishes a "first" and "second" reviewer beyond the fact that they do not
communicate before findings are produced.

## Every finding cites a rule

A finding is only a finding if it names the specific RULEBOOK rule it checks the translated code
against. "This looks wrong" or "I would have written it differently" is not a finding — it is an
opinion with no falsifiable anchor, and the protocol has no slot for those.

Two outcomes follow from this constraint:

1. The translated code violates a rule that exists in RULEBOOK → a finding, citing that rule, routed
   back to the translation step for correction.
2. The reviewer's objection is correct but no RULEBOOK rule covers it → not a finding against the
   code. It is a proposed rule amendment, and it travels a different route: to `rule-author-role`,
   between batches, never as a same-cycle correction to one file. RULEBOOK is read-only inside the
   loop; see `[[rulebook]]` for why and for the batch boundary that amendments wait for.

This split exists so a reviewer cannot smuggle a style preference into a code fix under the label
"finding." If the objection is worth acting on, it is worth being a rule everyone's work is checked
against from then on — that is the "fix the loop, not the code" principle, owned by `[[rulebook]]`,
not restated here.

A finding with no citable rule and no proposed amendment is dropped, not deferred.

## Arbiter on disagreement

An arbiter is invoked only when the two reviewer passes disagree on the same site — one raises a
finding the other does not, or the two findings conflict. Agreement between the two passes needs no
third opinion; invoking one anyway wastes a review cycle on a question that is already settled.

The arbiter receives both findings, the rule each one cites (or the absence of one), and the
translated code, and resolves which reading of the rule applies. The arbiter's ruling is final for
that cycle; it does not trigger a third independent pass, because the point of arbitration is to
break a tie, not to re-run the vote until it produces a different result.

If the disagreement traces back to the rule itself being ambiguous rather than to one reviewer
misreading it, that is itself a signal to route to `rule-author-role` as a rule amendment — the same
routing as an uncited finding, because an ambiguous rule is a rule that needs fixing, not a code site
that needs re-arguing every cycle it is re-encountered.

## Assigning model strength by role

Roles in this protocol are abstract tokens, not names of a specific agent or model tier — the
concrete assignment is an environment's business (e.g. a stronger model bound to the reviewer role,
a cheaper one bound to the implementer role in a given harness). The criterion for choosing strength
is **blast radius**, not which step happens to run more often:

- `rule-author-role` is strong. A rule written once is checked against every future translated file;
  an error here compounds silently across the whole migration instead of showing up once.
- `implementer-role` is cheaper. Translating one file against an already-stress-tested RULEBOOK is
  mechanical work with a small, local blast radius — a mistake here is caught by the next step, not
  propagated as policy.
- `adversarial-reviewer-role` is strong, for the same reason as the rule author: it is the
  independent check that catches what the implementer missed, and a weak reviewer that rubber-stamps
  a bad translation lets the error through with no remaining gate before it ships.

Blast radius, not job title, decides the tier: a role that is cheap to get wrong in one place stays
cheap; a role whose mistake propagates across the whole batch does not.
