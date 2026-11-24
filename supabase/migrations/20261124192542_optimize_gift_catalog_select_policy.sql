drop policy if exists "Public active gifts and admin catalog access" on public.gift_products;
create policy "Public active gifts and admin catalog access"
on public.gift_products for select to anon, authenticated
using (
  is_active = true
  or (((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin')
);
