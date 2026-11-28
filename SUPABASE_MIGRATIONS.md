# Supabase database deployment

HeyCutu is connected to the native Supabase GitHub integration.

## Integration settings

- Repository: `parthpratik18/HeyCutu`
- Working directory: `.` (the `supabase/` folder is at repository root)
- Production branch: `main`
- Automatic preview branches: Off (Free plan; no extra Supabase branches)
- Deploy to production: Keep OFF until migration history has been checked and baselined.

## Important: reconcile existing migration history first

The repository contains four migrations:

- `202610210001_private_game_sessions.sql`
- `202610310001_game_enhancements.sql`
- `202610310002_gameplay_logic_fixes.sql`
- `202611010001_game_room_lock_and_wheel_turn.sql`

The first three were previously applied manually through the Supabase SQL Editor. Supabase's GitHub deployment applies migration files that do not already have matching entries in `supabase_migrations.schema_migrations`. If those older versions are missing from migration history, enabling production deployment could try to run old SQL again.

Before enabling production deployment, inspect the migration history in the live project. If the table exists, check which of the first three versions are recorded. If it does not exist, do not enable deployment yet. The old versions must be marked as applied only after verifying that their SQL changes are present in production. `supabase migration repair --status applied <version>` updates migration history only; it does not run SQL.

Do not use the password-dependent GitHub Actions workflow in this repository. It is intentionally disabled. The Supabase native GitHub integration is the deployment mechanism.

## Going forward

Once history is reconciled, enable **Deploy to production** in Supabase. New timestamped files under `supabase/migrations/` merged into `main` will then be applied by Supabase. Never edit a migration after it has been applied; add a new migration for each later change.
