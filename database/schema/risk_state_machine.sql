-- Formal risk state machine for transaction, merchant and risk lifecycle

CREATE TABLE IF NOT EXISTS state_definitions (
  state_machine TEXT NOT NULL,
  state_name TEXT NOT NULL,
  is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (state_machine, state_name)
);

CREATE TABLE IF NOT EXISTS state_transitions (
  state_machine TEXT NOT NULL,
  from_state TEXT NOT NULL,
  to_state TEXT NOT NULL,
  transition_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (state_machine, from_state, to_state),
  FOREIGN KEY (state_machine, from_state) REFERENCES state_definitions(state_machine, state_name),
  FOREIGN KEY (state_machine, to_state) REFERENCES state_definitions(state_machine, state_name)
);

CREATE TABLE IF NOT EXISTS transaction_state_log (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  tx_id BIGINT NOT NULL,
  state_name TEXT NOT NULL,
  prev_state TEXT,
  transition_name TEXT,
  metadata JSONB,
  transitioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, tx_id, transitioned_at)
);

CREATE TABLE IF NOT EXISTS merchant_state_log (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  merchant_id BIGINT NOT NULL,
  state_name TEXT NOT NULL,
  prev_state TEXT,
  transition_name TEXT,
  metadata JSONB,
  transitioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS risk_state_log (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id BIGINT NOT NULL,
  state_name TEXT NOT NULL,
  prev_state TEXT,
  transition_name TEXT,
  metadata JSONB,
  transitioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION apply_state_transition(
  p_state_machine TEXT,
  p_tenant_id BIGINT,
  p_entity_type TEXT,
  p_entity_id BIGINT,
  p_to_state TEXT,
  p_metadata JSONB DEFAULT '{}'::JSONB
)
RETURNS BOOLEAN AS $$
DECLARE
  v_prev_state TEXT;
  v_transition TEXT;
BEGIN
  IF p_entity_type = 'TRANSACTION' THEN
    SELECT state_name INTO v_prev_state
    FROM transaction_state_log
    WHERE tenant_id = p_tenant_id AND tx_id = p_entity_id
    ORDER BY transitioned_at DESC LIMIT 1;
  ELSIF p_entity_type = 'MERCHANT' THEN
    SELECT state_name INTO v_prev_state
    FROM merchant_state_log
    WHERE tenant_id = p_tenant_id AND merchant_id = p_entity_id
    ORDER BY transitioned_at DESC LIMIT 1;
  ELSE
    SELECT state_name INTO v_prev_state
    FROM risk_state_log
    WHERE tenant_id = p_tenant_id AND entity_type = p_entity_type AND entity_id = p_entity_id
    ORDER BY transitioned_at DESC LIMIT 1;
  END IF;

  IF v_prev_state IS NULL THEN
    SELECT transition_name INTO v_transition
    FROM state_transitions
    WHERE state_machine = p_state_machine AND from_state = 'INITIAL' AND to_state = p_to_state;
  ELSE
    SELECT transition_name INTO v_transition
    FROM state_transitions
    WHERE state_machine = p_state_machine AND from_state = v_prev_state AND to_state = p_to_state;
  END IF;

  IF v_transition IS NULL THEN
    RAISE EXCEPTION 'Invalid transition % -> % for machine %', COALESCE(v_prev_state, 'INITIAL'), p_to_state, p_state_machine;
  END IF;

  IF p_entity_type = 'TRANSACTION' THEN
    INSERT INTO transaction_state_log (tenant_id, tx_id, state_name, prev_state, transition_name, metadata)
    VALUES (p_tenant_id, p_entity_id, p_to_state, v_prev_state, v_transition, p_metadata);
  ELSIF p_entity_type = 'MERCHANT' THEN
    INSERT INTO merchant_state_log (tenant_id, merchant_id, state_name, prev_state, transition_name, metadata)
    VALUES (p_tenant_id, p_entity_id, p_to_state, v_prev_state, v_transition, p_metadata);
  ELSE
    INSERT INTO risk_state_log (tenant_id, entity_type, entity_id, state_name, prev_state, transition_name, metadata)
    VALUES (p_tenant_id, p_entity_type, p_entity_id, p_to_state, v_prev_state, v_transition, p_metadata);
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
