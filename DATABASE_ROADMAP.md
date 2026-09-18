# Database Roadmap

## Completed foundation

- Await-first SQLite and PostgreSQL query builder with portable parameters.
- Transactional migrations, hidden self-healing runner, pending status,
  `--step`, read-only `--pretend`, `reset`, `fresh`, and production `--force`.
- Explicit seeders with `db:seed` and `migrate:fresh --seed`.
- Typed ORM: mapped/custom/nullable fields, native enum and `DateTime` casts,
  scopes, pagination, factories, dirty tracking, save, and lifecycle hooks.
- ORM relations: `belongsTo`, `hasOne`, `hasMany`, `belongsToMany`, nested
  eager loading, child creation, and pivot `attach`/`detach`/`sync`.

## Next work, in order

1. Schema ergonomics: named/droppable indexes, more portable `alterTable()`
   operations, and database-specific type-change guidance.
2. Relation depth: pivot attributes, relation query constraints, polymorphic
   relations, and optional relation-level ordering.
3. ORM data ergonomics: custom serialized field casts, value-object support,
   guarded/fillable field policies, and model validation integration.
4. Operational tooling: production-safe migration locking diagnostics and
   optional seeder selection (for example `jazzy db:seed demo_users`).

Keep `DB.table()` first-class throughout: it remains the recommended escape
hatch for joins, aggregates, bulk work, and database-specific SQL.
