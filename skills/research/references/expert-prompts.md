# Research Consortium — Expert Prompt Templates

Phase 2 launches each expert in one parallel message. Each agent runs independently — never share one agent's findings with another. Two **codebase-bound** tracks (Codebase, Architecture) use the verbatim prompts below on Explore / architecture-expert; the four **external** tracks (Web, Docs, Dependencies, OSS Examples) run on the `source-researcher` agent (see *External tracks* below).

> **Intentional overlap with the `write-spec` skill.** The Codebase / Architecture prompts
> here overlap with `../../write-spec/references/research-prompts.md`, where they appear as an
> enriched superset. The two files are kept separate **on purpose** so each skill stays
> self-contained — do not merge them into a shared file. (Both skills route external-source
> gathering through the same `source-researcher` agent + `rules/external-sources.md`, so that
> method *is* shared — only the codebase prompts are intentionally duplicated.)

All prompts must include this line: *"Respond in the same language as the research topic description."*

---

## Tool discovery & multi-channel use — single source

The method for discovering reachable tools/MCP, querying **all** relevant channels of a class,
and cross-checking by trust tier is **not duplicated here**. It lives in one place:
`rules/external-sources.md` § *Tool discovery & multi-channel use* (+ § *Verify library API
before code* for stack composition, § *Trust assessment* for tiers). That rule is unconditional
and is inherited by every subagent, so the `source-researcher` agent and the Explore /
architecture tracks all apply the same discipline without restating it.

The four **external** tracks (Web / Docs / Dependencies / OSS Examples) do not get a hardcoded
tool in their prompt — they run on the **`source-researcher`** agent, which does its own runtime
discovery. The two **codebase-bound** tracks keep their own prompts (Explore and architecture-expert
have different jobs and toolchains).

---

## External tracks — launch via the `source-researcher` agent

Web, Docs, Dependencies, and OSS Examples are four **independent** instances of `source-researcher`,
each with a different `focus` (independence per instance preserves the synthesis-bias invariant —
do not collapse them into one call). The agent already knows its method and report structure;
the launch prompt only supplies focus + topic + constraints. Model/effort are pinned in the
agent definition (`sonnet` / `medium`) — do not override unless the topic clearly needs more.

Launch each selected external track with `agentType: source-researcher` and this prompt:

```
focus: {web | library-docs | dependency-intelligence}
topic: {topic}
constraints: {known boundaries — KMP-only, no new deps, pinned versions, deadline}

Investigate only your focus class for this topic, per your standing instructions
(discover available channels → query all relevant ones → cross-check by tier → report
without synthesizing). Respond in the same language as the topic description.
```

Track → focus mapping:

| Track | `focus` | Covers |
|---|---|---|
| Web | `web` | industry practice, trade-offs, pitfalls, ≤12-mo developments, consensus — from articles and discussion (the *discourse* about an approach, not the code) |
| Docs | `library-docs` | API reference, guides, changelogs, migration/compat, version-specific behavior |
| Dependencies | `dependency-intelligence` | current vs latest versions, CVEs, KMP/AGP compat, health, breaking changes, alternatives |
| OSS Examples | `oss-examples` | real usages in open-source code, feasibility evidence ("does a working example exist?"), current wiring/integration patterns — pointers to repo/file/version, not embedded code. Channel catalog: `rules/external-sources.md` § *Каналы поиска по open-source коду* |

The detailed per-class angles that used to live here now live in the agent's system prompt
(`agents/source-researcher.md`) and in `external-sources.md` — single source, no restating.

---

## Codebase Expert (Explore subagent)

Use a structured code-index tool when available (resolves classes, usages, dependencies, API by symbol). Fall back to `Grep` + `Read` if no index — same report structure either way.

```
Investigate the codebase for everything related to: {topic}

Find and report:
1. Existing code that relates to this topic (classes, interfaces, modules)
2. Current patterns and approaches used for similar concerns
3. Dependencies already in the project that are relevant
4. Module boundaries and layers that would be affected
5. Any existing TODO/FIXME comments related to this topic

Use a code-index tool for symbol resolution when one is available; fall back to
Grep + Read otherwise. Check build files, configuration, and test code too.

Respond in the same language as the research topic description. Structure: overview,
then findings grouped by category.
```

---

## Architecture Expert (architecture-expert agent)

```
Evaluate the architectural implications of: {topic}

Analyze:
1. Which modules and layers would be affected?
2. Does this align with the current architecture, or does it require structural changes?
3. Dependency direction — would this introduce any problematic dependencies?
4. API boundaries — what contracts need to change or be created?
5. Integration points — where does this touch existing abstractions?

Read the relevant module structure and build files before making judgments.
Respond in the same language as the research topic description.
```
