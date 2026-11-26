---
name: game
description: Hand any game-design request to the senior-game-designer agent. Use whenever the user asks for anything about designing, critiquing, balancing or prototyping a game ("מעצב משחקים", "תעצב לי משחק", "רעיון למשחק", "אב-טיפוס", "GDD", "פלייטסט", "game designer").
argument-hint: "[what you want, e.g. design an original physics puzzle game]"
---

# Game designer on call

The user's request: **$ARGUMENTS**

Delegate it to the `senior-game-designer` subagent with the Agent tool
(`subagent_type: "senior-game-designer"`, `run_in_background: false`).

The subagent cannot see this conversation, so its prompt must be self-contained. Include:
- The request, word for word, plus any earlier game ideas, decisions, files or feedback from this
  conversation that bear on it (e.g. the existing `prototypes/<name>/` folder or GDD to continue from).
- That it should answer in Hebrew.
- Today's date.

If $ARGUMENTS is empty, ask the user what they want the game designer to do before delegating.

When it returns, give the user its result in Hebrew, in a short, plain form: what it designed or built,
the files it created, how to open a prototype (the path to its `index.html`), and any risk flags it raised.
Then ask what to change next. Each further request goes back to the same agent: continue it with
SendMessage if it is still available, otherwise launch it again with the context.
