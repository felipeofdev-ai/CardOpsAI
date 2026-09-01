-- LISTEN/NOTIFY wake-up for decision queue workers

CREATE OR REPLACE FUNCTION notify_decision_queue_wakeup()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify(
    'cardops_decision_queue',
    json_build_object(
      'queue_id', NEW.queue_id,
      'tenant_id', NEW.tenant_id,
      'status', NEW.status
    )::text
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_decision_queue_notify ON decision_queue;
CREATE TRIGGER trg_decision_queue_notify
  AFTER INSERT OR UPDATE OF status ON decision_queue
  FOR EACH ROW
  WHEN (NEW.status IN ('PENDING', 'pending'))
  EXECUTE FUNCTION notify_decision_queue_wakeup();

COMMENT ON FUNCTION notify_decision_queue_wakeup IS 'Wake async workers via pg_notify cardops_decision_queue';
