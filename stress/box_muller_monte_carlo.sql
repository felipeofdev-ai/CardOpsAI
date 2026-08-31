-- Box-Muller Monte Carlo VaR / CVaR (complements liquidity views below)

CREATE OR REPLACE FUNCTION run_monte_carlo_stress(
  p_iterations INT DEFAULT 1000,
  p_horizon_days INT DEFAULT 30,
  p_confidence NUMERIC DEFAULT 0.95,
  p_tenant_id BIGINT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_mu NUMERIC;
  v_sigma NUMERIC;
  v_iterations INT := GREATEST(p_iterations, 100);
  v_horizon INT := GREATEST(p_horizon_days, 1);
  v_u1 NUMERIC;
  v_u2 NUMERIC;
  v_z NUMERIC;
  v_day INT;
  v_loss NUMERIC;
  v_i INT;
  v_losses NUMERIC[] := ARRAY[]::NUMERIC[];
  v_idx95 INT;
  v_idx99 INT;
  v_var95 NUMERIC;
  v_var99 NUMERIC;
  v_cvar95 NUMERIC;
  v_mean NUMERIC;
  v_std NUMERIC;
BEGIN
  SELECT
    COALESCE(AVG(amount), 100),
    COALESCE(NULLIF(STDDEV_POP(amount), 0), 35)
  INTO v_mu, v_sigma
  FROM transactions
  WHERE upper(status) IN ('DECLINED', 'CHARGEBACK')
    AND (p_tenant_id IS NULL OR tenant_id = p_tenant_id);

  IF v_mu IS NULL OR v_mu <= 0 THEN v_mu := 100; END IF;
  IF v_sigma IS NULL OR v_sigma <= 0 THEN v_sigma := v_mu * 0.35; END IF;

  FOR v_i IN 1..v_iterations LOOP
    v_loss := 0;
    FOR v_day IN 1..v_horizon LOOP
      v_u1 := GREATEST(random(), 1e-12);
      v_u2 := GREATEST(random(), 1e-12);
      v_z := sqrt(-2 * ln(v_u1)) * cos(2 * pi() * v_u2);
      v_loss := v_loss + GREATEST(0, v_mu + v_sigma * v_z);
    END LOOP;
    v_losses := array_append(v_losses, v_loss);
  END LOOP;

  v_losses := (SELECT array_agg(x ORDER BY x) FROM unnest(v_losses) AS x);
  v_idx95 := GREATEST(1, CEIL(array_length(v_losses, 1) * 0.95)::INT);
  v_idx99 := GREATEST(1, CEIL(array_length(v_losses, 1) * 0.99)::INT);
  v_var95 := v_losses[v_idx95];
  v_var99 := v_losses[v_idx99];

  SELECT AVG(x) INTO v_cvar95 FROM unnest(v_losses) AS x WHERE x >= v_var95;
  SELECT AVG(x), STDDEV_POP(x) INTO v_mean, v_std FROM unnest(v_losses) AS x;

  RETURN jsonb_build_object(
    'iterations', v_iterations,
    'horizon_days', v_horizon,
    'confidence', p_confidence,
    'var_95', round(v_var95, 4),
    'var_99', round(v_var99, 4),
    'cvar_95', round(COALESCE(v_cvar95, v_var95), 4),
    'recommended_capital_reserve', round(COALESCE(v_cvar95, v_var95) * 1.2, 4),
    'mean_loss', round(COALESCE(v_mean, 0), 4),
    'std_loss', round(COALESCE(v_std, 0), 4)
  );
END;
$$ LANGUAGE plpgsql;
