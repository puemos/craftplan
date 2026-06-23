# Bottle order-report importer

Stage 1 — `extract.py`: turns a Bottle XLSX export into 4 CSVs under `runs/<ts>/`.
Stage 2 — `mix bottle.import <run_dir>`: ingests the CSVs into Craftplan.

See `docs/superpowers/specs/2026-06-22-bottle-import-design.md` for the design.
See `.claude/skills/bottle-import/SKILL.md` for the agent-facing workflow.

## Quickstart

    python3 -m venv .venv && source .venv/bin/activate
    pip install pandas openpyxl
    python extract.py /path/to/bottle.xlsx --from 2026-01-01 --to 2026-06-20
    # prints: priv/imports/bottle/runs/20260622T140000Z

    mix bottle.import priv/imports/bottle/runs/20260622T140000Z
