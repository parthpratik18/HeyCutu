-- Keep each invite locked to the game it was created for.
-- Apply this migration in Supabase SQL Editor after 202610310002_gameplay_logic_fixes.sql.

drop function if exists public.join_game_session(text,text);

create or replace function public.join_game_session(
  p_invite_token text,
  p_partner_name text,
  p_expected_game_type text
)
returns table(session_id uuid, partner_token text, questions jsonb, game_type text)
language plpgsql security definer set search_path=public,extensions as $$
declare
  v_row public.game_sessions%rowtype;
  v_partner text := encode(gen_random_bytes(24),'hex');
begin
  if nullif(trim(p_partner_name),'') is null or char_length(p_partner_name)>40 then
    raise exception 'Invalid name';
  end if;

  select s.* into v_row
  from public.game_sessions s
  join public.game_invites i on i.session_id=s.id
  where i.invite_token_hash=encode(digest(p_invite_token,'sha256'),'hex')
    and s.partner_token_hash is null
    and s.expires_at>now()
  for update of s;

  if not found then raise exception 'Invitation invalid, expired, or already used'; end if;
  if v_row.game_type is distinct from p_expected_game_type then
    raise exception 'This invite belongs to a different game. Open the matching game link.';
  end if;

  update public.game_sessions
  set partner_name=trim(p_partner_name),
      partner_token_hash=encode(digest(v_partner,'sha256'),'hex')
  where id=v_row.id;

  delete from public.game_invites where game_invites.session_id=v_row.id;

  return query select v_row.id,v_partner,v_row.questions,v_row.game_type;
end $$;

create or replace function public.submit_game_action(
  p_session_id uuid,
  p_participant_token text,
  p_action jsonb
)
returns table(
  partner_joined boolean, partner_name text, turn_role text, last_prompt text,
  creator_setup boolean, partner_answers boolean, result jsonb, game_state jsonb
)
language plpgsql security definer set search_path=public,extensions as $$
declare
  v_row public.game_sessions%rowtype;
  v_hash text := encode(digest(p_participant_token,'sha256'),'hex');
  v_role text;
  v_other_role text;
  v_type text := p_action->>'type';
  v_state jsonb;
  v_expected jsonb;
  v_answers jsonb;
  v_results jsonb;
  v_score int;
  v_item record;
  v_choices jsonb;
  v_step int;
  v_target_role text;
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

  v_other_role:=case when v_role='creator' then 'partner' else 'creator' end;
  if v_row.partner_token_hash is null then raise exception 'Waiting for your partner to join'; end if;
  v_state:=coalesce(v_row.game_state,'{}'::jsonb);

  if v_type='loyalty_setup' then
    if v_row.game_type<>'loyalty-test' or v_role<>v_row.turn_role
      or coalesce(v_state->>'loyalty_phase','setup')<>'setup' then
      raise exception 'It is not your turn to set answers';
    end if;
    v_expected:=p_action->'expected';
    if jsonb_typeof(v_expected)<>'object' or (select count(*) from jsonb_object_keys(v_expected))<>5 then
      raise exception 'Choose all five expected answers';
    end if;
    v_state:=jsonb_set(v_state,'{loyalty_expected}',coalesce(v_state->'loyalty_expected','{}'::jsonb)||jsonb_build_object(v_role,v_expected),true);
    v_state:=jsonb_set(v_state,'{loyalty_phase}','"guess"'::jsonb,true);
    update public.game_sessions
      set game_state=v_state,turn_role=v_other_role
      where id=p_session_id;

  elsif v_type='loyalty_answer' then
    if v_row.game_type<>'loyalty-test' or v_role<>v_row.turn_role
      or coalesce(v_state->>'loyalty_phase','setup')<>'guess' then
      raise exception 'It is not your turn to guess';
    end if;
    v_expected:=coalesce(v_state->'loyalty_expected'->v_other_role,'{}'::jsonb);
    v_answers:=p_action->'answers';
    if jsonb_typeof(v_expected)<>'object' or jsonb_typeof(v_answers)<>'object'
      or (select count(*) from jsonb_object_keys(v_answers))<>5 then
      raise exception 'Answer all five questions';
    end if;
    v_score:=0;
    for v_item in select key from jsonb_each(v_expected) loop
      if v_expected->v_item.key=v_answers->v_item.key then v_score:=v_score+1; end if;
    end loop;
    v_results:=coalesce(v_state->'loyalty_round_results','[]'::jsonb)||
      jsonb_build_array(jsonb_build_object('round',coalesce((v_state->>'round')::int,1),'setter',v_other_role,'score',v_score,'total',5));
    v_state:=jsonb_set(v_state,'{loyalty_round_results}',v_results,true);
    v_state:=jsonb_set(v_state,'{round}',to_jsonb(coalesce((v_state->>'round')::int,1)+1),true);
    v_state:=jsonb_set(v_state,'{loyalty_phase}','"setup"'::jsonb,true);
    v_state:=jsonb_set(v_state,'{loyalty_expected}','{}'::jsonb,true);
    update public.game_sessions
      set game_state=v_state,turn_role=v_role,loyalty_result=jsonb_build_object('score',v_score,'total',5)
      where id=p_session_id;

  elsif v_type='truthdare_turn' then
    if v_row.game_type<>'how-well' or v_role<>v_row.turn_role then
      raise exception 'Wait for your turn';
    end if;
    if nullif(trim(p_action->>'prompt'),'') is null then raise exception 'A prompt is required'; end if;
    v_target_role:=coalesce(p_action->>'target_role',v_other_role);
    if v_target_role not in ('creator','partner') then raise exception 'Invalid wheel result'; end if;
    update public.game_sessions
      set last_prompt=left(p_action->>'prompt',500),turn_role=v_target_role
      where id=p_session_id;

  elsif v_type='maze_choice' then
    if v_row.game_type<>'this-or-that' then raise exception 'This action is only for the heart maze'; end if;
    if (p_action->>'step') !~ '^[0-7]$' or (p_action->>'choice') !~ '^[0-1]$' then
      raise exception 'Invalid maze choice';
    end if;
    v_step:=(p_action->>'step')::int;
    v_choices:=coalesce(v_state->'maze_choices','{}'::jsonb);
    if jsonb_array_length(coalesce(v_choices->v_role,'[]'::jsonb))<>v_step then
      raise exception 'Refresh the room before continuing';
    end if;
    v_choices:=jsonb_set(v_choices,array[v_role],coalesce(v_choices->v_role,'[]'::jsonb)||
      jsonb_build_array(jsonb_build_object('step',v_step,'choice',(p_action->>'choice')::int)),true);
    v_state:=jsonb_set(v_state,'{maze_choices}',v_choices,true);
    update public.game_sessions set game_state=v_state where id=p_session_id;
  else
    raise exception 'Unknown game action';
  end if;

  return query select * from public.get_game_room(p_session_id,p_participant_token);
end $$;

revoke all on function public.join_game_session(text,text,text) from public;
grant execute on function public.join_game_session(text,text,text) to anon,authenticated;
revoke all on function public.submit_game_action(uuid,text,jsonb) from public;
grant execute on function public.submit_game_action(uuid,text,jsonb) to anon,authenticated;
