create or replace function public.gift_destination_get(p_product_id uuid)
returns text
language sql
security definer
set search_path = pg_catalog
as $$
  select d.destination_url
  from private.gift_product_destinations as d
  where d.product_id = p_product_id
  limit 1;
$$;

create or replace function public.gift_destination_list()
returns table(product_id uuid, destination_url text)
language sql
security definer
set search_path = pg_catalog
as $$
  select d.product_id, d.destination_url
  from private.gift_product_destinations as d;
$$;

create or replace function public.gift_destination_set(p_product_id uuid, p_destination_url text)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if p_destination_url !~ '^https?://' then
    raise exception 'Only HTTP or HTTPS destinations are allowed';
  end if;

  insert into private.gift_product_destinations(product_id, destination_url, updated_at)
  values (p_product_id, p_destination_url, now())
  on conflict (product_id) do update
    set destination_url = excluded.destination_url,
        updated_at = now();

  return true;
end;
$$;

revoke all on function public.gift_destination_get(uuid) from public, anon, authenticated;
revoke all on function public.gift_destination_list() from public, anon, authenticated;
revoke all on function public.gift_destination_set(uuid, text) from public, anon, authenticated;
grant execute on function public.gift_destination_get(uuid) to service_role;
grant execute on function public.gift_destination_list() to service_role;
grant execute on function public.gift_destination_set(uuid, text) to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('gift-images','gift-images',true,5242880,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public=true, file_size_limit=5242880, allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "Admins upload gift images" on storage.objects;
create policy "Admins upload gift images" on storage.objects
for insert to authenticated
with check (bucket_id='gift-images' and ((select auth.jwt())->'app_metadata'->>'role')='admin');

drop policy if exists "Admins update gift images" on storage.objects;
create policy "Admins update gift images" on storage.objects
for update to authenticated
using (bucket_id='gift-images' and ((select auth.jwt())->'app_metadata'->>'role')='admin')
with check (bucket_id='gift-images' and ((select auth.jwt())->'app_metadata'->>'role')='admin');

drop policy if exists "Admins delete gift images" on storage.objects;
create policy "Admins delete gift images" on storage.objects
for delete to authenticated
using (bucket_id='gift-images' and ((select auth.jwt())->'app_metadata'->>'role')='admin');

drop policy if exists "Public read gift images" on storage.objects;
create policy "Public read gift images" on storage.objects
for select to anon, authenticated
using (bucket_id='gift-images');
