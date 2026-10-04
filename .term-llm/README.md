# Project-local autonomy agent

Policy and operating contract: [autonomy guide](../docs/development/autonomy.md).

The installed `term-llm` supports an **explicit agent-directory path** containing
`agent.yaml` and `system.md`. This directory is not automatically discovered:
`agents new --local` uses `term-llm-agents/`, not `.term-llm/`. There is no claimed
`.term-llm/config.yaml` loader here. Use `.term-llm/agents/autonomy-pilot` explicitly
in the parent runner. Do not change global config or copy credentials here.
Source inspection also found a root `config.yaml` fallback after the global XDG
config search path; it is not a dependable project override and is outside this
setup's write scope. No such file is created.

Runner invocation fragment (not a standalone safe launcher):

```sh
term-llm --no-session loop --agent ./.term-llm/agents/autonomy-pilot \
  --approval prompt --max "$remaining_iterations" \
  '{{.term-llm/pilot-prompt.md}}'
```

The parent must validate `remaining_iterations` is an integer **1–5**, derived
from persisted counters under the shared flock. CLI `--max 0` means unlimited:
never invoke at zero. The loop flag limits only this invocation, not resumed
runs or repair approaches. The parent owns checkpointing, TERM handling, locks,
resource gates and `bin/autonomy-check`; this prompt cannot enforce them itself.
Approval mode is deliberately not `yolo`; unattended approvals need separate
bounded runner enforcement, not a blanket permission bypass. `--no-session`
avoids the CLI session database; it is not a full guarantee against all diagnostic
storage. No provider/model fields, `--provider`, or per-spawn overrides are set.

Discovery evidence: `term-llm version`, `loop --help`, `agents new --help`,
`agents show --help`; source `internal/agents/agent.go`, `registry.go` and
`internal/config/config.go` in the available CLI source checkout. Version tested:
`0.9.63-spawn-null-fix`, commit `f01ded0-local-spawn-fix`. Recheck schema after CLI
upgrades. Do not run bare `term-llm config`, `doctor`, or global agent export to
inspect configuration: they can expose global credentials or unrelated settings.
