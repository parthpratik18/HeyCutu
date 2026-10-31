# HeyCutu platform setup

## Included in this branch
- Animated responsive homepage, games directory and individual game routes.
- Birthday/anniversary wish builder, boyfriend/girlfriend gift pages, gift FAQs, About and Privacy.
- Page titles, descriptions, canonical URLs, sitemap and robots templates.
- Supabase migration with RLS enabled, no browser table reads, hashed invitation/participant tokens, single-use invites, seven-day session expiry and result-only-after-both-submitted RPCs.

## Supabase configuration
1. Create a Supabase project at https://supabase.com.
2. Run `supabase/migrations/202610210001_private_game_sessions.sql` in SQL Editor first (only if it has not already been applied).\n3. Then run `supabase/migrations/202610310001_game_enhancements.sql` in SQL Editor. This is additive: it adds room-state columns and two RPC functions; it does not drop existing game data or tables.\n4. In SQL Editor, verify the new functions exist with the verification query in the migration notes below.
5. In project API settings, copy the project URL and publishable/anon key.
6. Add VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in Vercel project environment variables, then redeploy the production branch after merging.
5. Never put the service-role key in a VITE_ variable; those values are exposed to browser code.

## Database verification query\nRun this after both migrations:\n\n```sql\nselect routine_name\nfrom information_schema.routines\nwhere routine_schema = 'public'\n  and routine_name in ('create_game_session','join_game_session','submit_game_answers','get_game_status','get_game_room','submit_game_action')\norder by routine_name;\n```\n\nYou should see six functions. The `game_sessions` table should now have `game_state`, `turn_role`, `last_prompt`, `creator_expected`, and `loyalty_result` columns.\n\n## Before production
- Test with two separate browsers/devices: first submit must return no result; second submit should reveal the computed result to both.
- Test invalid tokens, reused invite, duplicate submission and expired sessions.
- Add rate limits/CAPTCHA and scheduled cleanup before broad public release.
- Review the SQL in a non-production Supabase project first. Do not merge until migration and security tests pass.

## SEO / Search Console
Replace YOUR-DOMAIN in sitemap.xml and robots.txt with the final deployed domain. Verify the property in Google Search Console, submit /sitemap.xml, and use URL Inspection to request crawling. Indexing and ranking are not guaranteed.

## Known next step
Greeting pages currently use a URL-based preview; permanent saved public greeting URLs need a dedicated database table and creation/read policy. Privacy page is starter copy and should be reviewed for the actual live setup.
