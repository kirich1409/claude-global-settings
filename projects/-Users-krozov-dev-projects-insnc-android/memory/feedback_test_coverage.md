---
name: Always cover new code with unit tests
description: When writing new code, proactively add unit tests if possible; otherwise notify the user that tests are missing
type: feedback
---

Always cover new code with unit tests when possible. If the new code is testable (pure logic, utilities, formatters, mappers, etc.), write tests proactively without being asked. If tests are not feasible (Android UI code, framework-dependent code without test infrastructure), notify the user that the new code is not covered by tests and explain why.

**Why:** User expects test coverage for new code as a standard practice — discovered during MR !1066 review where `NumberFormatter` was shipped without tests and reviewer flagged it.

**How to apply:** After writing or modifying non-trivial logic, check if unit tests exist for it. If not, write them. Place tests in the module's `src/test/` directory following existing conventions (Kotest `StringSpec` or `ShouldSpec`, `shouldBe` matchers). If testing is blocked, mention it explicitly.
