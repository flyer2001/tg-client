#!/usr/bin/env bash
# Spike: ждать живое событие Long Poll до 5 минут, печатать сырой JSON (key вырезан).
cd "$(dirname "$0")/../.." && T=$(grep ^VK_BOT_TOKEN= .env | cut -d= -f2); G=$(grep ^VK_BOT_GROUP_ID= .env | cut -d= -f2)
S=$(curl -s "https://api.vk.com/method/groups.getLongPollServer" -d "group_id=$G&access_token=$T&v=5.199")
SRV=$(echo "$S" | python3 -c 'import json,sys;print(json.load(sys.stdin)["response"]["server"])')
KEY=$(echo "$S" | python3 -c 'import json,sys;print(json.load(sys.stdin)["response"]["key"])')
TS=$(echo "$S" | python3 -c 'import json,sys;print(json.load(sys.stdin)["response"]["ts"])')
echo "start ts=$TS $(date -u +%T)"
for i in $(seq 1 13); do
  R=$(curl -s "$SRV?act=a_check&key=$KEY&ts=$TS&wait=25")
  echo "$(date -u +%T) $R"
  TS=$(echo "$R" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("ts",""))')
  echo "$R" | grep -q message_new && break
done
