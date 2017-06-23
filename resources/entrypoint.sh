#!/usr/bin/env bash
service cron start && \
rm /var/run/apache2/apache2.pid 2>/dev/null || true && \
/usr/sbin/apache2ctl -D FOREGROUND
