---
name: recruit
description: Recruit a new specialist agent based on real, current market requirements. Use when the user asks to hire, recruit, create or build a new agent or subagent ("גייס סוכן", "תבנה לי סוכן", "סוכן חדש", "recruit an agent"). Clarifies the brief with the user, then delegates the research and the building to the agent-recruiter subagent.
argument-hint: "[role, e.g. ux researcher for a mobile car app]"
---

# Recruit a new agent

The user wants a new agent for the role: **$ARGUMENTS**

## 1. Clarify the brief (ask once, briefly)

Check `.claude/agents/` for an existing agent that already covers this role. If one does, tell the user and
ask whether to upgrade it or create a new one.

Then fill in the brief. Ask the user with AskUserQuestion, in one round of at most 4 questions, only for
what you cannot infer from the request and the repository. The fields:
- **Role and domain**: what exactly the agent is (e.g. "mobile UX researcher", "Israeli tax accountant").
- **Use in this project**: what tasks it will do here (look at the repository to suggest an answer).
- **Seniority**: junior, senior, or principal/expert (default: senior).
- **Market**: global, Israel, US, or EU (default: global plus Israel).
- **Answer language**: default is the user's language.
- **Hard limits**: anything it must never do or touch.

If $ARGUMENTS is empty, ask for the role first.

## 2. Delegate to the recruiter

Launch the `agent-recruiter` subagent with the Agent tool (`subagent_type: "agent-recruiter"`,
`run_in_background: false`). Pass the complete brief in the prompt: the role, the domain, the use in this project,
the seniority, the market, the language, the limits, a short description of what this repository is, and today's date.
The subagent cannot see this conversation, so include everything.

## 3. Review and hand over

When it returns:
- Read the new `.claude/agents/<name>.md`. Make sure the frontmatter is valid and the tools are least-privilege.
- Give the user a short summary in their language: who was "hired", the top competencies and where they
  came from, its tools and model, what it hands back to a human, and 3 example prompts.
- Mention that the new agent loads in a new session (or after `/agents`).
- Ask whether to commit and push the new agent and its research dossier to the repository, so that future
  cloud sessions keep it. Do not push without the user's okay.
