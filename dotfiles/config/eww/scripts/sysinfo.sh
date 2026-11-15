#!/usr/bin/env bash
case "$1" in
  cpu)
    top -bn1 | grep "Cpu(s)" | awk '{printf "%.0f", $2 + $4}'
    ;;
  ram)
    free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100.0}'
    ;;
esac
