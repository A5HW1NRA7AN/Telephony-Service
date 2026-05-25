#!/bin/bash
ssh -i ./freeswitch-key.pem -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i ./freeswitch-key.pem -o StrictHostKeyChecking=no -W %h:%p admin@43.206.227.215" admin@10.0.1.143 'docker exec telephony-postgres psql -P pager=off -U lead_user -d lead_db -c "SELECT id, processing_status, idempotency_key, sent_at FROM telephony_call_lead_ingest_log ORDER BY updated_at DESC LIMIT 3;"'
