-- Decision queue processor (uses original decision_queue columns)

CREATE OR REPLACE FUNCTION process_decision_queue(p_batch_size INT DEFAULT 100)
RETURNS JSONB AS $$
DECLARE
  v_item RECORD;
  v_txn RECORD;
  v_score NUMERIC;
  v_threshold NUMERIC;
  v_action TEXT;
  v_payload JSONB;
  v_processed INT := 0;
  v_approved INT := 0;
  v_declined INT := 0;
  v_review INT := 0;
  v_status TEXT;
BEGIN
  FOR v_item IN
    SELECT *
      FROM decision_queue
     WHERE upper(status) = 'PENDING'
     ORDER BY priority, queued_at
     LIMIT GREATEST(p_batch_size, 1)
     FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE decision_queue
       SET status = 'PROCESSING', started_at = cardops_now()
     WHERE queue_id = v_item.queue_id;

    BEGIN
      SELECT * INTO v_txn
        FROM transactions
       WHERE id = v_item.tx_id;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'tx % missing', v_item.tx_id;
      END IF;

      SELECT COALESCE(AVG(COALESCE(threshold, 50)), 50) INTO v_threshold
        FROM risk_rules
       WHERE COALESCE(is_active, active, TRUE);

      v_score := compute_risk_score(v_item.tx_id);

      IF v_score < v_threshold THEN
        v_action := 'APPROVE';
        v_status := 'APPROVED';
        v_approved := v_approved + 1;
      ELSIF v_score > (v_threshold * 2) THEN
        v_action := 'BLOCK';
        v_status := 'DECLINED';
        v_declined := v_declined + 1;
      ELSE
        v_action := 'REVIEW';
        v_status := 'APPROVED';
        v_review := v_review + 1;
      END IF;

      v_payload := jsonb_build_object(
        'tx_id', v_item.tx_id,
        'score', v_score,
        'threshold', v_threshold,
        'action', v_action
      );

      UPDATE transactions
         SET risk_score = v_score,
             decision = lower(v_action),
             decision_reason = v_payload,
             status = v_status,
             updated_at = cardops_now()
       WHERE id = v_item.tx_id;

      PERFORM append_tamper_evident_decision(
        v_txn.merchant_id,
        'tx:' || v_item.tx_id::text,
        v_score,
        v_action,
        NULL,
        NULL,
        v_item.tenant_id,
        v_payload,
        v_item.tx_id
      );

      UPDATE decision_queue
         SET status = 'DONE',
             finished_at = cardops_now()
       WHERE queue_id = v_item.queue_id;

      v_processed := v_processed + 1;
    EXCEPTION WHEN OTHERS THEN
      UPDATE decision_queue
         SET status = CASE WHEN retries + 1 >= max_retries THEN 'DEAD' ELSE 'PENDING' END,
             retries = retries + 1,
             last_error = SQLERRM
       WHERE queue_id = v_item.queue_id;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'processed', v_processed,
    'approved', v_approved,
    'declined', v_declined,
    'review', v_review
  );
END;
$$ LANGUAGE plpgsql;
