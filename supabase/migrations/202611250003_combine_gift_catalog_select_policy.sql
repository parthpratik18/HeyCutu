drop policy if exists "Admins can view all gifts" on public.gift_products;
drop policy if exists "Anyone can view active gifts" on public.gift_products;
create policy "Public active gifts and admin catalog access"
on public.gift_products for select to anon, authenticated
using (
  is_active = true
  or (select auth.jwt()->'app_metadata'->>'role') = 'admin'
);
