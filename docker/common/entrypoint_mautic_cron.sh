#!/bin/bash
set -e

echo "Starting Mautic Cron Service..."

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

# Create cron configuration
echo "Setting up cron jobs..."

# Define cron jobs based on Mautic requirements
# Segments update - every minute
echo "* * * * * www-data cd /var/www/html && php bin/console mautic:segments:update >> /var/log/cron.pipe 2>&1" >> /etc/cron.d/mautic

# Campaigns rebuild - every minute
echo "* * * * * www-data cd /var/www/html && php bin/console mautic:campaigns:rebuild >> /var/log/cron.pipe 2>&1" >> /etc/cron.d/mautic

# Campaigns trigger - every minute
echo "* * * * * www-data cd /var/www/html && php bin/console mautic:campaigns:trigger >> /var/log/cron.pipe 2>&1" >> /etc/cron.d/mautic

# Email send - every minute
echo "* * * * * www-data cd /var/www/html && php bin/console mautic:emails:send >> /var/log/cron.pipe 2>&1" >> /etc/cron.d/mautic

# Import - every 5 minutes
echo "*/5 * * * * www-data cd /var/www/html && php bin/console mautic:import >> /var/log/cron.pipe 2>&1" >> /etc/cron.d/mautic

# Broadcasts send - every minute
echo "* * * * * www-data cd /var/www/html && php bin/console mautic:broadcasts:send >> /var/log/cron.pipe 2>&1" >> /etc/cron.d/mautic

# Messages send - every minute
echo "* * * * * www-data cd /var/www/html && php bin/console mautic:messages:send >> /var/log/cron.pipe 2>&1" >> /etc/cron.d/mautic

# Webhooks process - every minute
echo "* * * * * www-data cd /var/www/html && php bin/console mautic:webhooks:process >> /var/log/cron.pipe 2>&1" >> /etc/cron.d/mautic

# Reports scheduler - every minute
echo "* * * * * www-data cd /var/www/html && php bin/console mautic:reports:scheduler >> /var/log/cron.pipe 2>&1" >> /etc/cron.d/mautic

# Apply proper permissions
chmod 0644 /etc/cron.d/mautic

# Start cron daemon
echo "Starting cron daemon..."
exec cron -f
