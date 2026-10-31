-- Multiplayer game logic hardening: alternating loyalty rounds and paired heart maze.
-- Apply after 202610310001_game_enhancements.sql.
create or replace function public.get_game_room(
  p_session_id uuid,
  p_participant_token text
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
  v_result jsonb;
  v_score int := 0;
  v_total int := 0;
  v_item record;
  v_choices jsonb;
  v_my_count int;
  v_partner_count int;
  v_expected jsonb;
  v_phase text;
begin
  select * into v_row from public.game_sessions
  where id=p_session_id and expires_at>now();
  if not found then raise exception 'Game not found or expired'; end if;
  if v_row.creator_token_hash=v_hash then v_role:='creator';
  elsif v_row.partner_token_hash=v_hash then v_role:='partner';
  else raise exception 'Invalid participant token'; end if;

  v_result:=v_row.loyalty_result;
  v_choices:=coalesce(v_row.game_state->'maze_choices','{}'::jsonb);
  v_my_count:=jsonb_array_length(coalesce(v_choices->v_role,'[]'::jsonb));
  v_partner_count:=jsonb_array_length(coalesce(v_choices->case when v_role='creator' then 'partner' else 'creator' end,'[]'::jsonb));
  v_phase:=coalesce(v_row.game_state->>'loyalty_phase','setup');
  v_expected:=coalesce(v_row.game_state->'loyalty_expected','{}'::jsonb);

  if v_row.game_type='love-match' and v_row.creator_answers is not null and v_row.partner_answers is not null then
    v_score:=0; v_total:=0;
    for v_item in select key from jsonb_each(v_row.creator_answers) loop
      v_total:=v_total+1;
      if v_row.creator_answers->v_item.key=v_row.partner_answers->v_item.key then v_score:=v_score+1; end if;
    end loop;
    v_result:=jsonb_build_object('score',v_score,'total',v_total);
  elsif v_row.game_type='loyalty-test' then
    v_result:=jsonb_build_object(
      'score',coalesce((select sum((x->>'score')::int) from jsonb_array_elements(coalesce(v_row.game_state->'loyalty_round_results','[]'::jsonb)) x),0),
      'total',coalesce(jsonb_array_length(coalesce(v_row.game_state->'loyalty_round_results','[]'::jsonb)),0)*5,
      'round',coalesce((v_row.game_state->>'round')::int,1),
      'round_results',coalesce(v_row.game_state->'loyalty_round_results','[]'::jsonb)
    );
  elsif v_row.game_type='this-or-that' and v_my_count=8 and v_partner_count=8 then
    v_score:=0; v_total:=8;
    for v_item in select value from jsonb_array_elements(coalesce(v_choices->'creator','[]'::jsonb)) loop
      if (v_choices->'partner')->((v_item.value->>'step')::int) is not null
         and (v_choices->'partner')->((v_item.value->>'step')::int)->>'choice'=v_item.value->>'choice' then
        v_score:=v_score+1;
      end if;
    end loop;
    v_result:=jsonb_build_object('score',v_score,'total',v_total,
      'summary',format('You guessed %s of 8 of your partner’s choices. Keep discovering each other!',v_score));
  end if;

  return query select
    v_row.partner_token_hash is not null,
    v_row.partner_name,
    v_row.turn_role,
    v_row.last_prompt,
    (v_phase='guess'),
    (v_row.partner_answers is not null),
    v_result,
    jsonb_build_object(
      'round',coalesce((v_row.game_state->>'round')::int,1),
      'loyalty_phase',v_phase,
      'loyalty_expected',case when v_phase='guess' then v_expected->case when v_role='creator' then 'partner' else 'creator' end else null end,
      'loyalty_round_results',coalesce(v_row.game_state->'loyalty_round_results','[]'::jsonb),
      'maze_choices',v_choices,
      'creator_submitted',v_row.creator_answers is not null,
      'partner_submitted',v_row.partner_answers is not null,
      'my_maze_count',v_my_count,
      'partner_maze_count',v_partner_count
    );
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
  v_type text := p_action->>'type';
  v_state jsonb;
  v_expected jsonb;
  v_answers jsonb;
  v_results jsonb;
  v_score int;
  v_item record;
  v_choices jsonb;
  v_step int;
begin
  if jsonb_typeof(p_action)<>'object' or length(p_action::text)>12000 then raise exception 'Invalid game action'; end if;
  select * into v_row from public.game_sessions
  where id=p_session_id and expires_at>now() for update;
  if not found then raise exception 'Game not found or expired'; end if;
  if v_row.creator_token_hash=v_hash then v_role:='creator';
  elsif v_row.partner_token_hash=v_hash then v_role:='partner';
  else raise exception 'Invalid participant token'; end if;
  if v_row.partner_token_hash is null then raise exception 'Waiting for your partner to join'; end if;
  v_state:=coalesce(v_row.game_state,'{}'::jsonb);

  if v_type='loyalty_setup' then
    if v_row.game_type<>'loyalty-test' or v_role<>v_row.turn_role
      or coalesce(v_state->>'loyalty_phase','setup')<>'setup' then
      raise exception 'It is not your turn to set answers'; end if;
    v_expected:=p_action->'expected';
    if jsonb_typeof(v_expected)<>'object' or (select count(*) from jsonb_object_keys(v_expected))<>5 then raise exception 'Choose all five expected answers'; end if;
    v_state:=jsonb_set(v_state,'{loyalty_expected}',coalesce(v_state->'loyalty_expected','{}'::jsonb)||jsonb_build_object(v_role,v_expected),true);
    v_state:=jsonb_set(v_state,'{loyalty_phase}','"guess"'::jsonb,true);
    update public.game_sessions set game_state=v_state,turn_role=case when v_role='creator' then 'partner' else 'creator' end
      where id=p_session_id;

  elsif v_type='loyalty_answer' then
    if v_row.game_type<>'loyalty-test' or v_role<>v_row.turn_role
      or coalesce(v_state->>'loyalty_phase','setup')<>'guess' then raise exception 'It is not your turn to guess'; end if;
    v_expected:=coalesce(v_state->'loyalty_expected'->case when v_role='creator' then 'partner' else 'creator' end,'{}'::jsonb);
    v_answers:=p_action->'answers';
    if jsonb_typeof(v_expected)<>'object' or jsonb_typeof(v_answers)<>'object'
      or (select count(*) from jsonb_object_keys(v_answers))<>5 then raise exception 'Answer all five questions'; end if;
    v_score:=0;
    for v_item in select key from jsonb_each(v_expected) loop
      if v_expected->v_item.key=v_answers->v_item.key then v_score:=v_score+1; end if;
    end loop;
    v_results:=coalesce(v_state->'loyalty_round_results','[]'::jsonb)||
      jsonb_build_array(jsonb_build_object('round',coalesce((v_state->>'round')::int,1),'setter',case when v_role='creator' then 'partner' else 'creator' end,'score',v_score,'total',5));
    v_state:=jsonb_set(v_state,'{loyalty_round_results}',v_results,true);
    v_state:=jsonb_set(v_state,'{round}',to_jsonb(coalesce((v_state->>'round')::int,1)+1),true);
    v_state:=jsonb_set(v_state,'{loyalty_phase}','"setup"'::jsonb,true);
    v_state:=jsonb_set(v_state,'{loyalty_expected}','{}'::jsonb,true);
    update public.game_sessions set game_state=v_state,turn_role=v_role,loyalty_result=jsonb_build_object('score',v_score,'total',5)
      where id=p_session_id;

  elsif v_type='truthdare_turn' then
    if v_row.game_type<>'how-well' or v_role<>v_row.turn_role then raise exception 'Wait for your turn'; end if;
    if nullif(trim(p_action->>'prompt'),'') is null then raise exception 'A prompt is required'; end if;
    update public.game_sessions set last_prompt=left(p_action->>'prompt',500),
      turn_role=case when v_role='creator' then 'partner' else 'creator' end
      where id=p_session_id;

  elsif v_type='maze_choice' then
    if v_row.game_type<>'this-or-that' then raise exception 'This action is only for the heart maze'; end if;
    if (p_action->>'step') !~ '^[0-7]$' or (p_action->>'choice') !~ '^[0-1]$' then raise exception 'Invalid maze choice'; end if;
    v_step:=(p_action->>'step')::int;
    v_choices:=coalesce(v_state->'maze_choices','{}'::jsonb);
    if jsonb_array_length(coalesce(v_choices->v_role,'[]'::jsonb))<>v_step then raise exception 'Refresh the room before continuing'; end if;
    v_choices:=jsonb_set(v_choices,array[v_role],coalesce(v_choices->v_role,'[]'::jsonb)||
      jsonb_build_array(jsonb_build_object('step',v_step,'choice',(p_action->>'choice')::int)),true);
    v_state:=jsonb_set(v_state,'{maze_choices}',v_choices,true);
    update public.game_sessions set game_state=v_state where id=p_session_id;
  else
    raise exception 'Unknown game action';
  end if;

  return query select * from public.get_game_room(p_session_id,p_participant_token);
end $$;

revoke all on function public.get_game_room(uuid,text) from public;
revoke all on function public.submit_game_action(uuid,text,jsonb) from public;
grant execute on function public.get_game_room(uuid,text) to anon,authenticated;
grant execute on function public.submit_game_action(uuid,text,jsonb) to anon,authenticated;
