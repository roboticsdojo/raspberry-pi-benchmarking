#!/bin/bash

OUTPUT="thermal_log.csv"
echo "time,temp,arm_freq" > $OUTPUT

START=$(date +%s)

while true
do
  NOW=$(date +%s)
  ELAPSED=$((NOW-START))

  TEMP=$(vcgencmd measure_temp | cut -d= -f2 | tr -d "'C")
  FREQ=$(vcgencmd measure_clock arm | cut -d= -f2)

  echo "$ELAPSED,$TEMP,$FREQ" >> $OUTPUT

  sleep 5
done
