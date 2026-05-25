#!/bin/bash
ssh -i ./freeswitch-key.pem -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i ./freeswitch-key.pem -o StrictHostKeyChecking=no -W %h:%p admin@43.206.227.215" admin@10.0.1.143 'docker exec telephony-freeswitch fs_cli -p CluSt3r@Esl#2026! -x "originate loopback/1000/public &playback(/usr/share/freeswitch/sounds/custom/greeting.wav)"'
