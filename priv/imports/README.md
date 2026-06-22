# priv/imports/

Mapping files and append-only logs used by the import skills (see `.claude/skills/`).

## Files

- **`igf_material_map.yml`** — IGF supplier product code → Craftplan material SKU. Updated by the [`igf-import`](../../.claude/skills/igf-import/SKILL.md) skill each time a new line is mapped. Mirrors `Material.external_sku` for redundancy and offline lookup.
- **`igf_price_history.jsonl`** — Append-only log of every invoice line that's been imported, including the converted Craftplan-unit quantity and per-unit price. Survives a database wipe; useful for re-running imports against a fresh DB and for cross-checking `Lot.unit_cost` series.

## Why both?

`Lot.unit_cost` is the schema-level source of truth for material cost over time. These files are belt-and-suspenders:

1. They give the skill a way to recover state if a Craftplan write fails mid-import.
2. They make it easy to spot drift between what the skill *meant* to write and what's actually in the database.
3. They're the disaster-recovery archive — if the database ever gets restored from a backup that pre-dates an import, we can replay from the log.
