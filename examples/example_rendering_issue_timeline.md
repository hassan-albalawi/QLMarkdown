# Unified Skills Model: Commands + Skills = One System

**Date**: 2026-01-16 | **Version**: Claude Code 2.1.3+

---

## The Change

```mermaid
graph LR
    subgraph "Before 2.1.3"
        C1["/commands/*.md"]
        S1["/skills/*/SKILL.md"]
        C1 -.->|"SlashCommand tool"| E1["User invokes"]
        S1 -.->|"Skill tool"| E2["Model invokes"]
    end

    subgraph "After 2.1.3 (NOW)"
        U["All .md files"]
        U -->|"Single Skill tool"| B["Both can invoke"]
    end

    style C1 fill:#e74c3c,stroke:#333,color:#fff
    style S1 fill:#3498db,stroke:#333,color:#fff
    style U fill:#2ecc71,stroke:#333,color:#fff
```

---

## Timeline

```mermaid
timeline
    title Claude Code Skills Evolution

    0.2.31 : .claude/commands/ becomes slash commands
    1.0.30 : Commands support bash, file mentions
    2.0.20 : Skills introduced (separate system)
    2.1.0 : Skills hot-reload, context:fork
    2.1.3 : MERGE - Commands and Skills unified
    2.1.6 : Nested skills auto-discovery
    2.1.9 : Session ID substitution
```

---

## What Changed

| Aspect | Before | After |
|--------|--------|-------|
| **Tools** | `SlashCommand` + `Skill` | Single `Skill` tool |
| **Invocation** | Commands = user, Skills = model | Both can be either |
| **Location** | `/commands/` vs `/skills/` | Both work the same |
| **Behavior** | Different systems | Identical behavior |
| **Frontmatter** | Similar but separate | Unified spec |

---

## Unified File Structure

```mermaid
graph TD
    subgraph ".claude/"
        subgraph "Option A: Single File"
            CMD["commands/plan.md"]
        end

        subgraph "Option B: Directory + Resources"
            SKL["skills/pdf/"]
            SKL --> SM["SKILL.md"]
            SKL --> SC["scripts/"]
            SKL --> ST["templates/"]
        end
    end

    CMD -->|"Same behavior"| INV["Invoke via /plan or Skill tool"]
    SM -->|"Same behavior"| INV

    style CMD fill:#3498db,stroke:#333,color:#fff
    style SM fill:#3498db,stroke:#333,color:#fff
    style INV fill:#2ecc71,stroke:#333
```

---

## When to Use Each

```mermaid
flowchart TD
    Q1{{"Need helper scripts/templates?"}}
    Q1 -->|Yes| D["Use skills/ directory"]
    Q1 -->|No| Q2{{"Complex multi-step?"}}

    Q2 -->|Yes| D
    Q2 -->|No| F["Use commands/ file"]

    D --> R1["skills/name/SKILL.md<br/>+ scripts/, data/"]
    F --> R2["commands/name.md"]

    style D fill:#9b59b6,stroke:#333,color:#fff
    style F fill:#3498db,stroke:#333,color:#fff
```

| Scenario | Recommendation |
|----------|----------------|
| Simple prompt/workflow | `commands/name.md` |
| Needs scripts | `skills/name/SKILL.md` |
| Needs templates/data | `skills/name/SKILL.md` |
| Expert domain knowledge | `commands/experts/domain/` |

---

## Frontmatter Reference

```yaml
---
# Identity
name: skill-name              # Display name
description: What it does     # Shows in /help and tool list

# Invocation Control
user-invocable: true          # Show in slash menu (default: true)
disable-model-invocation: false  # Prevent Skill tool use

# Execution
allowed-tools: Read, Glob, Bash  # Tool whitelist
model: opus                   # Force specific model
context: fork                 # Run in forked context

# Arguments
argument-hint: [file] [options]  # Help text for args
---
```

---

## Impact on Our Repository

```mermaid
graph TB
    subgraph "Current Structure (Valid)"
        C[".claude/commands/"]
        C --> C1["plan.md"]
        C --> C2["build.md"]
        C --> C3["infra.md"]
        C --> EX["experts/"]
        EX --> E1["adw/"]
        EX --> E2["websocket/"]

        S[".claude/skills/"]
        S --> S1["start-orchestrator/"]
        S --> S2["meta-skill/"]
    end

    subgraph "How It Works Now"
        ALL["All are Skills"]
        ALL --> USER["/command → User invokes"]
        ALL --> MODEL["Skill tool → Model invokes"]
    end

    C --> ALL
    S --> ALL

    style ALL fill:#2ecc71,stroke:#333
```

### No Changes Needed

| Current | Status | Reason |
|---------|--------|--------|
| `commands/*.md` | Works | Unified as skills |
| `skills/*/SKILL.md` | Works | Native format |
| `experts/*/expertise.yaml` | Works | Custom pattern |
| `agents/*.md` | Works | Task tool pattern |

---

## Key Insight

```mermaid
mindmap
  root((Unified Model))
    Mental Shift
      Not "commands vs skills"
      Just "skills"
      Location is organization
      Not behavior
    Our Pattern
      commands/ for simple prompts
      skills/ for complex + resources
      experts/ for domain knowledge
      agents/ for subagent configs
```

---

## Migration Recommendations

```mermaid
flowchart LR
    subgraph "Keep As-Is"
        K1["commands/plan.md"]
        K2["commands/build.md"]
        K3["commands/infra.md"]
        K4["skills/start-orchestrator/"]
    end

    subgraph "Consider Upgrading"
        U1["commands/experts/ →<br/>Could be skills/ with<br/>expertise.yaml as resource"]
    end

    style K1 fill:#2ecc71,stroke:#333
    style K2 fill:#2ecc71,stroke:#333
    style K3 fill:#2ecc71,stroke:#333
    style K4 fill:#2ecc71,stroke:#333
    style U1 fill:#f39c12,stroke:#333
```

| Decision | Action |
|----------|--------|
| Keep structure | Yes - works with unified model |
| Rename commands → skills | Optional - no behavior change |
| Move experts to skills | Consider - enables helper scripts |

---

## Summary

```
BEFORE                           AFTER
══════                           ═════
commands/ = user-invoked    →    All are "skills"
skills/ = model-invoked     →    All can be either
SlashCommand tool           →    Single Skill tool
Two mental models           →    One mental model
```

**Bottom Line**: Our current structure is valid. The merge simplified Claude Code internals without requiring changes from us.

---

## Sources

- [Claude Code Changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Slash Commands Documentation](https://code.claude.com/docs/en/slash-commands)
- [Inside Claude Code Skills - Mikhail Shilkov](https://mikhail.io/2025/10/claude-code-skills/)
