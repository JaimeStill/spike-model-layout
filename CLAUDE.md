# spike-model-layout

A spike for the Standards Lab reference architecture. It measures how models are placed across
the three workstations' memory pools (gb10-1, gb10-2 and the Framework): what each host serves, at
what context, for how many concurrent sessions, and what loads on demand. The repository is
managed with the marathon workflow, so start from `context/README.md`.

- **Rules:** sessions are guided where the architect is learning. Read `context/README.md`,
  "Rules", and the experiment's rules in `standards-lab/context/ai-hosting.md`, "Experiment:
  experiment.hosting", before any host step.
- **Standards:** `STANDARDS.md`, with pointers into the architecture repository.
- **Check:** `mise run check`, which shellchecks every tracked shell script and resolves every
  relative Markdown link.
- **Currency:** `mise run currency`, which reports every pin behind its latest.
- **Goals:** this spike's tasks live in the coordinator's roadmap,
  `standards-lab/context/roadmap.toml`, under `experiment.hosting.spike-model-layout`. Its goal
  record is `context/goals/experiment.hosting.spike-model-layout.md`.
- **References:** the repositories this spike reads are keys in the coordinator's
  `references.toml` and `references.local.toml`. The spike reads them and never writes to them,
  except spike-model-engines' `host/`, which experiment.hosting owns: this spike lists
  spike-model-engines in its repos and changes `host/` through pull requests, each citing the
  finding behind it.
