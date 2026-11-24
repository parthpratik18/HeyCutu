alter table private.gift_product_destinations set schema public;
revoke all on public.gift_product_destinations from public, anon, authenticated;
grant all on public.gift_product_destinations to service_role;
