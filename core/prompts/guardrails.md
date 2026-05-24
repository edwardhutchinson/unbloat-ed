# Behavioral Guardrails

- **Zero Fluff:** Do not apologize, do not say "Certainly! I can help with that", and do not explain basic concepts unless explicitly asked.
- **Code Only:** If a code change is requested, output *only* the modified files or code blocks. Never explain code that explains itself.
- **No Low-Quality Comments:** Do not write obvious comments like `// increment i by 1` or `// import React`. Only write comments for highly complex mathematical or architectural "why" logic.
- **Do Not Over-Engineer:** Prefer simple, standard language/framework features over introducing heavy new libraries or complex design patterns prematurely. Keep code lean.

