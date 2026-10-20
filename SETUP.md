# HeyCutu platform setup

## Included in this branch
- Animated responsive homepage, games directory and individual game routes.
- Birthday/anniversary wish builder, boyfriend/girlfriend gift pages, gift FAQs, About and Privacy.
- Page titles, descriptions, canonical URLs, sitemap and robots templates.
- Supabase migration with RLS enabled, no browser table reads, hashed invitation/participant tokens, single-use invites, seven-day session expiry and result-only-after-both-submitted RPCs.

## Supabase configuration
1. Create a Supabase project at https://supabase.com.
2. Run supabase/migrations/202610210001_private_game_sessions.sql in SQL Editor.
3. In project API settings, copy the project URL and publishable/anon key.
4. Add VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in Vercel project environment variables, then redeploy this branch preview.
5. Never put the service-role key in a VITE_ variable; those values are exposed to browser code.

## Before production
- Test with two separate browsers/devices: first submit must return no result; second submit should reveal the computed result to both.
- Test invalid tokens, reused invite, duplicate submission and expired sessions.
- Add rate limits/CAPTCHA and scheduled cleanup before broad public release.
- Review the SQL in a non-production Supabase project first. Do not merge until migration and security tests pass.

## SEO / Search Console
Replace YOUR-DOMAIN in sitemap.xml and robots.txt with the final deployed domain. Verify the property in Google Search Console, submit /sitemap.xml, and use URL Inspection to request crawling. Indexing and ranking are not guaranteed.

## Known next step
Greeting pages currently use a URL-based preview; permanent saved public greeting URLs need a dedicated database table and creation/read policy. Privacy page is starter copy and should be reviewed for the actual live setup.
