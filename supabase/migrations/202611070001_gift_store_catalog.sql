create table if not exists public.gift_products (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  description text not null default '' check (char_length(description) <= 500),
  price_label text check (price_label is null or char_length(price_label) <= 40),
  category text check (category is null or char_length(category) <= 80),
  image_url text,
  destination_url text not null,
  is_featured boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gift_products_destination_https check (destination_url ~ '^https?://'),
  constraint gift_products_image_https check (image_url is null or image_url ~ '^https?://')
);

alter table public.gift_products enable row level security;

drop policy if exists "Anyone can view active gifts" on public.gift_products;
create policy "Anyone can view active gifts"
on public.gift_products for select
to anon, authenticated
using (is_active = true);

drop policy if exists "Admins can view all gifts" on public.gift_products;
create policy "Admins can view all gifts"
on public.gift_products for select
to authenticated
using ((select auth.jwt()->'app_metadata'->>'role') = 'admin');

drop policy if exists "Admins can insert gifts" on public.gift_products;
create policy "Admins can insert gifts"
on public.gift_products for insert
to authenticated
with check ((select auth.jwt()->'app_metadata'->>'role') = 'admin');

drop policy if exists "Admins can update gifts" on public.gift_products;
create policy "Admins can update gifts"
on public.gift_products for update
to authenticated
using ((select auth.jwt()->'app_metadata'->>'role') = 'admin')
with check ((select auth.jwt()->'app_metadata'->>'role') = 'admin');

drop policy if exists "Admins can delete gifts" on public.gift_products;
create policy "Admins can delete gifts"
on public.gift_products for delete
to authenticated
using ((select auth.jwt()->'app_metadata'->>'role') = 'admin');

grant select on public.gift_products to anon, authenticated;
grant insert, update, delete on public.gift_products to authenticated;
