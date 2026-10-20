create extension if not exists pgcrypto with schema extensions;

create table if not exists public.game_sessions (
 id uuid primary key default gen_random_uuid(),
 game_type text not null check(game_type in ('love-match','loyalty-test','how-well','this-or-that')),
 creator_name text not null check(char_length(creator_name) between 1 and 40),
 partner_name text,
 questions jsonb not null default '[]'::jsonb,
 creator_token_hash text not null,
 partner_token_hash text,
 creator_answers jsonb,
 partner_answers jsonb,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '7 days',
 check(jsonb_typeof(questions)='array')
);
create table if not exists public.game_invites(
 session_id uuid primary key references public.game_sessions(id) on delete cascade,
 invite_token_hash text not null unique,
 created_at timestamptz not null default now()
);
alter table public.game_sessions enable row level security;
alter table public.game_invites enable row level security;
revoke all on public.game_sessions,public.game_invites from anon,authenticated;

create or replace function public.create_game_session(p_game_type text,p_creator_name text,p_questions jsonb)
returns table(session_id uuid,invite_token text,creator_token text)
language plpgsql security definer set search_path=public,extensions as $$
declare v_id uuid; v_invite text:=encode(gen_random_bytes(24),'hex'); v_creator text:=encode(gen_random_bytes(24),'hex');
begin
 if p_game_type not in ('love-match','loyalty-test','how-well','this-or-that') then raise exception 'Unsupported game type'; end if;
 if nullif(trim(p_creator_name),'') is null or char_length(p_creator_name)>40 then raise exception 'Invalid name'; end if;
 if jsonb_typeof(p_questions)<>'array' or jsonb_array_length(p_questions)<1 or jsonb_array_length(p_questions)>20 then raise exception 'Invalid questions'; end if;
 insert into public.game_sessions(id,game_type,creator_name,questions,creator_token_hash) values(gen_random_uuid(),p_game_type,trim(p_creator_name),p_questions,encode(digest(v_creator,'sha256'),'hex')) returning id into v_id;
 insert into public.game_invites(session_id,invite_token_hash) values(v_id,encode(digest(v_invite,'sha256'),'hex'));
 return query select v_id,v_invite,v_creator;
end $$;

create or replace function public.join_game_session(p_invite_token text,p_partner_name text)
returns table(session_id uuid,partner_token text,questions jsonb,game_type text)
language plpgsql security definer set search_path=public,extensions as $$
declare v_row public.game_sessions%rowtype; v_partner text:=encode(gen_random_bytes(24),'hex');
begin
 if nullif(trim(p_partner_name),'') is null or char_length(p_partner_name)>40 then raise exception 'Invalid name'; end if;
 select s.* into v_row from public.game_sessions s join public.game_invites i on i.session_id=s.id where i.invite_token_hash=encode(digest(p_invite_token,'sha256'),'hex') and s.partner_token_hash is null and s.expires_at>now() for update;
 if not found then raise exception 'Invitation invalid, expired, or already used'; end if;
 update public.game_sessions set partner_name=trim(p_partner_name),partner_token_hash=encode(digest(v_partner,'sha256'),'hex') where id=v_row.id;
 delete from public.game_invites where game_invites.session_id=v_row.id;
 return query select v_row.id,v_partner,v_row.questions,v_row.game_type;
end $$;

create or replace function public.submit_game_answers(p_session_id uuid,p_partner_token text,p_answers jsonb)
returns table(partner1_submitted boolean,partner2_submitted boolean,result jsonb)
language plpgsql security definer set search_path=public,extensions as $$
declare v_row public.game_sessions%rowtype; v_hash text:=encode(digest(p_partner_token,'sha256'),'hex'); v_score int:=0; v_total int:=0; v_item record;
begin
 if jsonb_typeof(p_answers)<>'object' or length(p_answers::text)>12000 then raise exception 'Invalid answers'; end if;
 select * into v_row from public.game_sessions where id=p_session_id and expires_at>now() for update;
 if not found then raise exception 'Game not found or expired'; end if;
 if v_row.creator_token_hash=v_hash then
  if v_row.creator_answers is not null then raise exception 'Already submitted'; end if;
  update public.game_sessions set creator_answers=p_answers where id=p_session_id returning * into v_row;
 elsif v_row.partner_token_hash=v_hash then
  if v_row.partner_answers is not null then raise exception 'Already submitted'; end if;
  update public.game_sessions set partner_answers=p_answers where id=p_session_id returning * into v_row;
 else raise exception 'Invalid participant token'; end if;
 if v_row.creator_answers is not null and v_row.partner_answers is not null then
  for v_item in select key from jsonb_each(v_row.creator_answers) loop v_total:=v_total+1; if v_row.creator_answers->v_item.key=v_row.partner_answers->v_item.key then v_score:=v_score+1; end if; end loop;
  return query select true,true,jsonb_build_object('score',v_score,'total',v_total,'summary',format('You matched on %s of %s answers. Keep learning little things about each other!',v_score,v_total));
 else return query select v_row.creator_answers is not null,v_row.partner_answers is not null,null::jsonb; end if;
end $$;

create or replace function public.get_game_status(p_session_id uuid,p_partner_token text)
returns table(partner1_submitted boolean,partner2_submitted boolean,result jsonb)
language plpgsql security definer set search_path=public,extensions as $$
declare v_row public.game_sessions%rowtype; v_hash text:=encode(digest(p_partner_token,'sha256'),'hex'); v_score int:=0; v_total int:=0; v_item record; v_result jsonb:=null;
begin
 select * into v_row from public.game_sessions where id=p_session_id and expires_at>now();
 if not found then raise exception 'Game not found or expired'; end if;
 if v_row.creator_token_hash<>v_hash and coalesce(v_row.partner_token_hash,'')<>v_hash then raise exception 'Invalid participant token'; end if;
 if v_row.creator_answers is not null and v_row.partner_answers is not null then
  for v_item in select key from jsonb_each(v_row.creator_answers) loop v_total:=v_total+1; if v_row.creator_answers->v_item.key=v_row.partner_answers->v_item.key then v_score:=v_score+1; end if; end loop;
  v_result:=jsonb_build_object('score',v_score,'total',v_total,'summary',format('You matched on %s of %s answers. Keep learning little things about each other!',v_score,v_total));
 end if;
 return query select v_row.creator_answers is not null,v_row.partner_answers is not null,v_result;
end $$;
revoke all on function public.create_game_session(text,text,jsonb) from public;
revoke all on function public.join_game_session(text,text) from public;
revoke all on function public.submit_game_answers(uuid,text,jsonb) from public;
revoke all on function public.get_game_status(uuid,text) from public;
grant execute on function public.create_game_session(text,text,jsonb) to anon,authenticated;
grant execute on function public.join_game_session(text,text) to anon,authenticated;
grant execute on function public.submit_game_answers(uuid,text,jsonb) to anon,authenticated;
grant execute on function public.get_game_status(uuid,text) to anon,authenticated;
