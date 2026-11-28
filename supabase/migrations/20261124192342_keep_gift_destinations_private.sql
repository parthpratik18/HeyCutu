create schema if not exists private;
do $$
begin
  if to_regclass('public.gift_product_destinations') is not null then
    alter table public.gift_product_destinations set schema private;
  end if;
end
$$;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;
revoke all on private.gift_product_destinations from public, anon, authenticated;
grant all on private.gift_product_destinations to service_role;
