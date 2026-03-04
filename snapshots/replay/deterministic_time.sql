-- Deterministic time control for replay and simulation

CREATE OR REPLACE FUNCTION cardops_now()
RETURNS TIMESTAMPTZ AS $$
DECLARE
  v_replay_time TEXT;
BEGIN
  v_replay_time := current_setting('cardops.replay_time', true);
  IF v_replay_time IS NULL OR v_replay_time = '' THEN
    RETURN NOW();
  END IF;
  RETURN v_replay_time::TIMESTAMPTZ;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION set_replay_time(p_time TIMESTAMPTZ)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('cardops.replay_time', p_time::TEXT, true);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clear_replay_time()
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('cardops.replay_time', '', true);
END;
$$ LANGUAGE plpgsql;
