#!/bin/bash
set -e

# Main entrypoint that routes to role-specific scripts

# Display debug information if enabled
if [ "$DEBUG" = "true" ]; then
    echo "=== DEBUG MODE ENABLED ==="
    echo "DOCKER_MAUTIC_ROLE: $DOCKER_MAUTIC_ROLE"
    echo "MAUTIC_DB_HOST: $MAUTIC_DB_HOST"
    echo "MAUTIC_DB_USER: $MAUTIC_DB_USER"
    echo "MAUTIC_DB_DATABASE: $MAUTIC_DB_DATABASE"
    env
    echo "=== END DEBUG INFO ==="
fi

# Route to appropriate role script
case "$DOCKER_MAUTIC_ROLE" in
    mautic_cron)
        exec /entrypoint_mautic_cron.sh "$@"
        ;;
    mautic_worker)
        exec /entrypoint_mautic_worker.sh "$@"
        ;;
    *)
        exec /entrypoint_mautic_web.sh "$@"
        ;;
esac
