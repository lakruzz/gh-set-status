---
applyTo: "**"
---

When in agent mode, creating intermediate or temporary test files, always create them in the ./temp folder which is ignored by git

In general avoid being too generous when suggesting print statements. We're developing a CLI for developers and we usually do not like verbose informative statements. As a rule of thumb, If nothing happened, then nothing should be printed. I'll let you know explicitly when print statements are needed.
