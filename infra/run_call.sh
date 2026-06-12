#!/bin/bash
ssh -i ./freeswitch-key.pem -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i ./freeswitch-key.pem -o StrictHostKeyChecking=no -W %h:%p ubuntu@18.183.139.53" ubuntu@10.0.1.143 'kubectl exec -n default deployment/freeswitch -- fs_cli -p CluSt3r@Esl#2026! -x "originate loopback/1000/public &playback(/usr/share/freeswitch/sounds/custom/greeting.wav)"'
