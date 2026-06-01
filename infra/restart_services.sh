#!/bin/bash
ssh -i freeswitch-key.pem -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i freeswitch-key.pem -o StrictHostKeyChecking=no -W %h:%p admin@52.69.97.143" admin@10.0.1.143 'cd /home/admin/freeswitch && docker compose up -d --build event-publisher freeswitch lead-service'
