create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;
revoke all on private.gift_product_destinations from public, anon, authenticated;
grant all on private.gift_product_destinations to service_role;
