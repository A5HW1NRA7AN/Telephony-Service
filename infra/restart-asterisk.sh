#!/bin/bash
echo "=== Full Asterisk Restart ==="
sudo systemctl restart asterisk
sleep 5
sudo systemctl status asterisk --no-pager
