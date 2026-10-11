"""The only module that talks to subtr-actor, so a change in its API is fixed here alone."""

from importlib import metadata


def parser_name() -> str:
    try:
        return f"subtr-actor {metadata.version('subtr-actor-py')}"
    except metadata.PackageNotFoundError:
        return "subtr-actor (unknown version)"


def read_replay(path: str) -> dict:
    """subtr-actor's frame-by-frame replay data, at the replay's own sample times
    (no resampling). The shape `clean.build_document` expects:

    - frame_data.metadata_frames[i]: time, seconds_remaining, replicated_game_state_name,
      replicated_game_state_time_remaining
    - frame_data.ball_data.frames[i]: "Empty" or {"Data": {"rigid_body": ...}}
    - frame_data.players[j] = [player_id, {"frames": [...]}], each frame "Empty" or
      {"Data": {rigid_body, boost_amount, boost_active, jump_active, double_jump_active,
      dodge_active, powerslide_active, input{throttle, steer, dodge_torque}, is_team_0,
      player_name}}
    - meta.team_zero / team_one: players with remote_id, name, car_body_id, car_hitbox_family
    - meta.all_headers: the replay header's (name, value) pairs
    - goal_events, demolish_infos, touch_events, boost_pads, boost_pad_events
    """
    import subtr_actor  # imported here so the rest of the converter (and its tests) runs without it

    return subtr_actor.get_replay_frames_data(path)
