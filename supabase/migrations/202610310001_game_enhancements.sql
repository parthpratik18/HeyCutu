-- HeyCutu multiplayer game enhancements (non-destructive)
-- Run once in Supabase SQL Editor AFTER the existing private_game_sessions migration.
alter table public.game_sessions
  add column if not exists game_state jsonb not null default '{}'::jsonb,
  add column if not exists turn_role text not null default 'creator',
  add column if not exists last_prompt text,
  add column if not exists creator_expected jsonb,
  add column if not exists loyalty_result jsonb;

-- Existing rooms keep their data. Truth or Dare uses the existing how-well game type.
alter table public.game_sessions drop constraint if exists game_sessions_turn_role_check;
alter table public.game_sessions add constraint game_sessions_turn_role_check
  check (turn_role in ('creator','partner'));

create or replace function public.get_game_room(
  p_session_id uuid,
  p_participant_token text
)
returns table(
  partner_joined boolean,
  partner_name text,
  turn_role text,
  last_prompt text,
  creator_setup boolean,
  partner_answers boolean,
  result jsonb,
  game_state jsonb
)
language plpgsql security definer set search_path=public,extensions as $$
declare
  v_row public.game_sessions%rowtype;
  v_hash text := encode(digest(p_participant_token,'sha256'),'hex');
  v_result jsonb;
  v_score int := 0;
  v_total int := 0;
  v_item record;
begin
  select * into v_row from public.game_sessions
  where id=p_session_id and expires_at>now();
  if not found then raise exception 'Game not found or expired'; end if;
  if v_row.creator_token_hash<>v_hash and coalesce(v_row.partner_token_hash,'')<>v_hash then
    raise exception 'Invalid participant token';
  end if;
  v_result:=v_row.loyalty_result;
  if v_row.game_type='love-match' and v_row.creator_answers is not null and v_row.partner_answers is not null then
    for v_item in select key from jsonb_each(v_row.creator_answers) loop
      v_total:=v_total+1;
      if v_row.creator_answers->v_item.key=v_row.partner_answers->v_item.key then v_score:=v_score+1; end if;
    end loop;
    v_result:=jsonb_build_object('score',v_score,'total',v_total,'summary',format('You matched on %s of %s answers. Keep learning each other!',v_score,v_total));
  end if;
  return query select
    v_row.partner_token_hash is not null,
    v_row.partner_name,
    v_row.turn_role,
    v_row.last_prompt,
    v_row.creator_expected is not null,
    v_row.partner_answers is not null,
    v_result,
    jsonb_build_object('round',coalesce((v_row.game_state->>'round')::int,1),
      'maze_choices',coalesce(v_row.game_state->'maze_choices','[]'::jsonb));
end $$;

create or replace function public.submit_game_action(
  p_session_id uuid,
  p_participant_token text,
  p_action jsonb
)
returns table(
  partner_joined boolean,
  partner_name text,
  turn_role text,
  last_prompt text,
  creator_setup boolean,
  partner_answers boolean,
  result jsonb,
  game_state jsonb
)
language plpgsql security definer set search_path=public,extensions as $$
declare
  v_row public.game_sessions%rowtype;
  v_hash text := encode(digest(p_participant_token,'sha256'),'hex');
  v_role text;
  v_expected jsonb;
  v_answers jsonb;
  v_score int := 0;
  v_total int := 0;
  v_item record;
  v_type text := p_action->>'type';
  v_state jsonb;
  v_result jsonb;
begin
  if jsonb_typeof(p_action)<>'object' or length(p_action::text)>12000 then
    raise exception 'Invalid game action';
  end if;
  select * into v_row from public.game_sessions
  where id=p_session_id and expires_at>now() for update;
  if not found then raise exception 'Game not found or expired'; end if;
  if v_row.creator_token_hash=v_hash then v_role:='creator';
  elsif v_row.partner_token_hash=v_hash then v_role:='partner';
  else raise exception 'Invalid participant token'; end if;
  if v_row.partner_token_hash is null then raise exception 'Waiting for your partner to join'; end if;
  v_state:=coalesce(v_row.game_state,'{}'::jsonb);

  if v_type='loyalty_setup' then
    if v_role<>v_row.turn_role then raise exception 'It is your partner''s turn to set the answers'; end if;
    v_expected:=p_action->'expected';
    if jsonb_typeof(v_expected)<>'object' or (select count(*) from jsonb_object_keys(v_expected))<>5 then
      raise exception 'Choose all five expected answers';
    end if;
    update public.game_sessions set creator_expected=v_expected, partner_answers=null, loyalty_result=null
      where id=p_session_id returning * into v_row;

  elsif v_type='loyalty_answer' then
    if v_role=v_row.turn_role then raise exception 'Your partner needs to answer this round'; end if;
    if v_row.creator_expected is null then raise exception 'Waiting for expected answers'; end if;
    v_answers:=p_action->'answers';
    if jsonb_typeof(v_answers)<>'object' or (select count(*) from jsonb_object_keys(v_answers))<>5 then
      raise exception 'Answer all five questions';
    end if;
    for v_item in select key from jsonb_each(v_row.creator_expected) loop
      v_total:=v_total+1;
      if v_row.creator_expected->v_item.key=v_answers->v_item.key then v_score:=v_score+1; end if;
    end loop;
    v_result:=jsonb_build_object('score',v_score,'total',v_total,
      'summary',case when v_score>=4 then 'Your partner knows your heart so well! 💖'
      when v_score>=2 then 'A sweet effort — keep learning each other’s little details.'
      else 'Looks like there are still a few things to discover together. Make it a cute conversation!' end);
    update public.game_sessions set
      loyalty_result=v_result,
      turn_role=v_role,
      creator_expected=null,
      partner_answers=null,
      game_state=jsonb_set(v_state,'{round}',to_jsonb(coalesce((v_state->>'round')::int,1)+1),true)
    where id=p_session_id returning * into v_row;

  elsif v_type='truthdare_turn' then
    if v_role<>v_row.turn_role then raise exception 'Wait for your turn'; end if;
    if nullif(trim(p_action->>'prompt'),'') is null then raise exception 'A prompt is required'; end if;
    update public.game_sessions set last_prompt=left(p_action->>'prompt',500),
      turn_role=case when v_role='creator' then 'partner' else 'creator' end
      where id=p_session_id returning * into v_row;

  elsif v_type='maze_choice' then
    if (p_action->>'step') !~ '^[0-9]+$' or (p_action->>'choice') not in ('0','1') then
      raise exception 'Invalid maze choice';
    end if;
    v_state:=jsonb_set(v_state,'{maze_choices}',coalesce(v_state->'maze_choices','[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('step',(p_action->>'step')::int,'choice',(p_action->>'choice')::int,'by',v_role)),true);
    update public.game_sessions set game_state=v_state where id=p_session_id returning * into v_row;
  else
    raise exception 'Unknown game action';
  end if;

  return query select v_row.partner_token_hash is not null,v_row.partner_name,v_row.turn_role,v_row.last_prompt,
    v_row.creator_expected is not null,v_row.partner_answers is not null,v_row.loyalty_result,
    jsonb_build_object('round',coalesce((v_row.game_state->>'round')::int,1),
      'maze_choices',coalesce(v_row.game_state->'maze_choices','[]'::jsonb));
end $$;

revoke all on function public.get_game_room(uuid,text) from public;
revoke all on function public.submit_game_action(uuid,text,jsonb) from public;
grant execute on function public.get_game_room(uuid,text) to anon,authenticated;
grant execute on function public.submit_game_action(uuid,text,jsonb) to anon,authenticated;
