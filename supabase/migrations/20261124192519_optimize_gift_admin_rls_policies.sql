drop policy if exists "Admins can insert gifts" on public.gift_products;
create policy "Admins can insert gifts"
on public.gift_products for insert to authenticated
with check (((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "Admins can update gifts" on public.gift_products;
create policy "Admins can update gifts"
on public.gift_products for update to authenticated
using (((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin')
with check (((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "Admins can delete gifts" on public.gift_products;
create policy "Admins can delete gifts"
on public.gift_products for delete to authenticated
using (((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin');
