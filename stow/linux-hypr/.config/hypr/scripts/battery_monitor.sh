#!/bin/sh

while true; do
    batteries=$(upower -e | grep BAT)
    low_count=0
    critical_count=0
    total_bats=$(echo "$batteries" | wc -l)

    if [ "$total_bats" -eq 0 ]; then
      exit
    fi

    for bat in $batteries; do
        percent=$(upower -i "$bat" | awk '/percentage:/ {print $2}' | tr -d '%')
        state=$(upower -i "$bat" | awk '/state:/ {print $2}')

        if [ "$state" = "discharging" ]; then
            if [ "$percent" -le 10 ]; then
                critical_count=$((critical_count + 1))
            elif [ "$percent" -le 20 ]; then
                low_count=$((low_count + 1))
            fi
        fi
    done

    if [ "$critical_count" -eq "$total_bats" ]; then
	notify-send -u critical -a "battery" -i battery-level-0-symbolic "Critical battery level, shutting down..."
        sleep 5
        systemctl poweroff
    elif [ "$low_count" -eq "$total_bats" ]; then
	notify-send -u normal -a "battery" -i battery-level-20-symbolic "Low battery; all batteries under 20%"
    fi

    sleep 120
done
