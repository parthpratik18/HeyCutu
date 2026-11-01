# Supabase database setup (one time)

After this setup, database migrations are applied automatically when a change containing files in `supabase/migrations/` is merged into `main`. You should not need to paste SQL into the Supabase SQL Editor for every feature.

## One-time GitHub setup

In the GitHub repository, open **Settings → Secrets and variables → Actions → New repository secret** and add:

- `SUPABASE_ACCESS_TOKEN`: a Supabase personal access token.
- `SUPABASE_DB_PASSWORD`: the database password for project `cactocxhfkmvdgurodxa`.

Do not put either value in source code or commit them.

## Existing database baseline

The first workflow run checks migration history. The first three migrations were previously applied manually in the Supabase SQL Editor, so if they are missing from Supabase's migration-history table, the workflow records those three as already applied. It does not rerun their SQL. It then runs `supabase db push`, which applies only genuinely pending newer migrations.

This baseline step is safe only because those three earlier migrations have already been applied to this project. If the database was reset or any of those SQL scripts were not actually run, stop and reconcile the schema before enabling the workflow.

## Going forward

1. Add each database change as a new timestamped SQL file under `supabase/migrations/`.
2. Commit it with the app changes.
3. Merge the PR into `main`.
4. GitHub Actions applies pending migrations automatically and records them in Supabase history.

Never edit an old migration after it has been applied. Create a new migration file for every later change.
