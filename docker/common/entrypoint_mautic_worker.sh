#!/bin/bash
set -e

echo "Starting Mautic Worker Service..."

# Verify required environment variables
if [ -z "$MAUTIC_DB_HOST" ]; then
    echo "ERROR: MAUTIC_DB_HOST is required"
    exit 1
fi

if [ -z "$MAUTIC_DB_USER" ]; then
    echo "ERROR: MAUTIC_DB_USER is required"
    exit 1
fi

if [ -z "$MAUTIC_DB_PASSWORD" ]; then
    echo "ERROR: MAUTIC_DB_PASSWORD is required"
    exit 1
fi

if [ -z "$MAUTIC_DB_DATABASE" ]; then
    echo "ERROR: MAUTIC_DB_DATABASE is required"
    exit 1
fi

# Set default worker counts if not specified
WORKERS_CONSUME_EMAIL=${DOCKER_MAUTIC_WORKERS_CONSUME_EMAIL:-2}
WORKERS_CONSUME_HIT=${DOCKER_MAUTIC_WORKERS_CONSUME_HIT:-2}
WORKERS_CONSUME_FAILED=${DOCKER_MAUTIC_WORKERS_CONSUME_FAILED:-2}

echo "Worker configuration:"
echo "  Email workers: $WORKERS_CONSUME_EMAIL"
echo "  Hit workers: $WORKERS_CONSUME_HIT"
echo "  Failed workers: $WORKERS_CONSUME_FAILED"

# Create supervisord configuration dynamically
cat > /etc/supervisor/conf.d/mautic-workers.conf <<EOF
[supervisord]
nodaemon=true
user=www-data
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:mautic-worker-email]
command=php /var/www/html/bin/console messenger:consume async --time-limit=300 --memory-limit=256M
directory=/var/www/html
autostart=true
autorestart=true
stopasgroup=true
numprocs=$WORKERS_CONSUME_EMAIL
redirect_stderr=true
stdout_logfile=/var/log/mautic/worker-email.log

[program:mautic-worker-hit]
command=php /var/www/html/bin/console messenger:consume hit --time-limit=300 --memory-limit=256M
directory=/var/www/html
autostart=true
autorestart=true
stopasgroup=true
numprocs=$WORKERS_CONSUME_HIT
redirect_stderr=true
stdout_logfile=/var/log/mautic/worker-hit.log

[program:mautic-worker-failed]
command=php /var/www/html/bin/console messenger:consume failed --time-limit=300 --memory-limit=256M
directory=/var/www/html
autostart=true
autorestart=true
stopasgroup=true
numprocs=$WORKERS_CONSUME_FAILED
redirect_stderr=true
stdout_logfile=/var/log/mautic/worker-failed.log
EOF

# Create log directories
mkdir -p /var/log/supervisor /var/log/mautic
chown -R www-data:www-data /var/log/mautic

# Start supervisord
echo "Starting supervisord with worker processes..."
exec supervisord -c /etc/supervisor/supervisord.conf
