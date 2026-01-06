#!/bin/bash
set -e

echo "Starting Mautic Web Service..."

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

# Verify volume mounts are writable
echo "Checking volume mounts..."
for dir in /var/www/html/config /var/www/html/var/logs /var/www/html/docroot/media/files /var/www/html/docroot/media/images; do
    if [ ! -d "$dir" ]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi
    if [ ! -w "$dir" ]; then
        echo "ERROR: Directory $dir is not writable by www-data"
        ls -la "$dir" || true
        chown -R www-data:www-data "$dir" || true
        chmod -R 775 "$dir" || true
    fi
done

# Run migrations if enabled
if [ "$DOCKER_MAUTIC_RUN_MIGRATIONS" = "true" ]; then
    echo "Running database migrations..."
    cd /var/www/html
    php bin/console doctrine:migrations:migrate --no-interaction || echo "Migration completed with warnings"
fi

# Load test data if enabled
if [ "$DOCKER_MAUTIC_LOAD_TEST_DATA" = "true" ]; then
    echo "Loading test data..."
    cd /var/www/html
    php bin/console mautic:install:load --force
fi

# Start Apache
echo "Starting Apache web server..."
exec apache2-foreground
