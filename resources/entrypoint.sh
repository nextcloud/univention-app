#!/usr/bin/env bash
if [ -f "/var/www/html/occ" ]; then
    IS_INSTALLED=$(sudo -u www-data php /var/www/html/occ status | grep installed | awk '{ print $3; }')
    if [ "${IS_INSTALLED}" == "true" ]; then
      # Apply one-click-instance settings...
      sudo -u www-data php /var/www/html/occ config:system:set one-click-instance --value=true --type=bool
      sudo -u www-data php /var/www/html/occ config:system:set one-click-instance.user-limit --value=500 --type=int
      sudo -u www-data php /var/www/html/occ config:system:set one-click-instance.link --value="https://nextcloud.com/univention/"
      sudo -u www-data php /var/www/html/occ app:enable support
    fi
    unset IS_INSTALLED
fi

service cron start && \
rm /var/run/apache2/apache2.pid 2>/dev/null || true && \
/usr/sbin/apache2ctl -D FOREGROUND
