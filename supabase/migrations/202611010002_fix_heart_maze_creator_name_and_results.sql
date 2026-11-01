-- Return the creator's name to both room participants and expose shared maze progress.
create or replace function public.get_game_room(
  p_session_id uuid,
  p_participant_token text
)
returns table(
  partner_joined boolean, partner_name text, turn_role text, last_prompt text,
  creator_setup boolean, partner_answers boolean, result jsonb, game_state jsonb
)
language plpgsql security definer set search_path=public,extensions as $function$
declare
  v_row public.game_sessions%rowtype;
  v_hash text := encode(digest(p_participant_token,'sha256'),'hex');
  v_role text;
  v_other_role text;
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
  v_other_role:=case when v_role='creator' then 'partner' else 'creator' end;
  v_result:=v_row.loyalty_result;
  v_choices:=coalesce(v_row.game_state->'maze_choices','{}'::jsonb);
  v_my_count:=jsonb_array_length(coalesce(v_choices->v_role,'[]'::jsonb));
  v_partner_count:=jsonb_array_length(coalesce(v_choices->v_other_role,'[]'::jsonb));
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
      'round_results',coalesce(v_row.game_state->'loyalty_round_results','[]'::jsonb));
  elsif v_row.game_type='this-or-that' and v_my_count=8 and v_partner_count=8 then
    v_score:=0; v_total:=8;
    for v_item in select value from jsonb_array_elements(coalesce(v_choices->'creator','[]'::jsonb)) loop
      if (v_choices->'partner')->((v_item.value->>'step')::int) is not null
         and (v_choices->'partner')->((v_item.value->>'step')::int)->>'choice'=v_item.value->>'choice' then
        v_score:=v_score+1;
      end if;
    end loop;
    v_result:=jsonb_build_object('score',v_score,'total',v_total,
      'summary',format('You matched %s of 8 choices. Keep discovering each other!',v_score));
  end if;
  return query select
    v_row.partner_token_hash is not null,v_row.partner_name,v_row.turn_role,v_row.last_prompt,
    (v_phase='guess'),(v_row.partner_answers is not null),v_result,
    jsonb_build_object(
      'creator_name',v_row.creator_name,
      'round',coalesce((v_row.game_state->>'round')::int,1),
      'loyalty_phase',v_phase,
      'loyalty_expected',case when v_phase='guess' then v_expected->v_other_role else null end,
      'loyalty_round_results',coalesce(v_row.game_state->'loyalty_round_results','[]'::jsonb),
      'maze_choices',v_choices,
      'creator_submitted',v_row.creator_answers is not null,
      'partner_submitted',v_row.partner_answers is not null,
      'my_maze_count',v_my_count,'partner_maze_count',v_partner_count);
end;
$function$;
revoke all on function public.get_game_room(uuid,text) from public;
grant execute on function public.get_game_room(uuid,text) to anon,authenticated;
notify pgrst,'reload schema';
