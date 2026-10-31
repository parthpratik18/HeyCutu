# HeyCutu platform setup

## Supabase configuration

Run the migrations in this order in Supabase SQL Editor:

1. `202610210001_private_game_sessions.sql` — only if the original private game session schema has not already been applied.
2. `202610310001_game_enhancements.sql` — adds multiplayer room state and the first enhanced room RPCs. If you already ran this migration, do not rerun it.
3. `202610310002_gameplay_logic_fixes.sql` — replaces the room RPCs with the corrected alternating Loyalty Test rounds, private role-specific expected answers, per-player Heart Maze progress and paired maze scoring.

The second migration is additive and does not drop existing tables or session data. Existing game rooms created before the new game-state format should be treated as old sessions; create new rooms for testing.

## Verify the database

Run after all three migrations:

```sql
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'create_game_session',
    'join_game_session',
    'submit_game_answers',
    'get_game_status',
    'get_game_room',
    'submit_game_action'
  )
order by routine_name;
```

You should see six function names. Confirm the `game_sessions` table includes `game_state`, `turn_role`, `last_prompt`, `creator_expected`, and `loyalty_result`.

## Vercel configuration

Set `VITE_SUPABASE_URL` to the Supabase project API URL and `VITE_SUPABASE_ANON_KEY` to the publishable/anon key. Never put a service-role key in a `VITE_` variable. Vercel should build the feature branch as a Preview deployment; production remains on `main` until the pull request is merged.

## Two-player test checklist

- Create a fresh room in one browser and join it from another browser/device.
- Love Match: both participants submit once; neither sees a score until both submit; both then see the same score.
- Loyalty Test: creator sets five expected answers, partner guesses; then partner sets five answers and creator guesses. Confirm cumulative score increases across both rounds and neither setter's expected answers are exposed to the other participant before guessing.
- Truth or Dare: confirm names appear on the wheel, it animates, turns alternate, and skip advances the turn without pressure.
- Heart Maze: both players independently complete all eight choices; after both finish, compare the two sets and show the shared match count.
- Refresh either browser mid-game and confirm its room and progress recover.
- Test an invalid invite, a reused invite, duplicate Love Match submission and expired room.

Instagram sharing uses the device's native share sheet when available; otherwise the app copies the invite link so the user can paste it into Instagram. It cannot force a direct Instagram DM or story post from a website.

Do not merge to production until the migration has been applied and the two-browser tests pass.
