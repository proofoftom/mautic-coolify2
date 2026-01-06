# Mautic 7.x Docker Deployment for Coolify

Production-ready Docker deployment configuration for Mautic 7.x (Marketing Automation Platform) optimized for Coolify, featuring RabbitMQ message queuing, MySQL 8.0, and persistent volume mounts for themes and plugins.

## Architecture

This deployment consists of 5 services:

| Service | Description | Port |
|---------|-------------|------|
| **mysql** | MySQL 8.0 database | 3306 |
| **rabbitmq** | RabbitMQ 3 message broker | 5672 |
| **mautic_web** | Apache + PHP 8.4 web server | 80 |
| **mautic_cron** | Background task scheduler | - |
| **mautic_worker** | RabbitMQ queue consumer | - |

## Quick Start

### 1. Deploy in Coolify

1. Create a new project in Coolify
2. Create a new service using "Docker Compose" type
3. Paste the contents of `docker-compose.yml`
4. Configure environment variables (Coolify will auto-generate passwords)
5. Deploy

### 2. Initial Installation

On first deployment, enable migrations:

```bash
# In Coolify environment variables, set:
MAUTIC_RUN_MIGRATIONS=true
```

Then access your Mautic instance at the configured domain to complete the web-based installation.

## Directory Structure

```
mautic-coolify/
├── docker-compose.yml          # Coolify compose file
├── docker/                     # Custom Docker build files
│   ├── Dockerfile              # Multi-stage Dockerfile for Mautic 7.x
│   ├── common/
│   │   ├── docker-entrypoint.sh
│   │   ├── entrypoint_mautic_web.sh
│   │   ├── entrypoint_mautic_cron.sh
│   │   ├── entrypoint_mautic_worker.sh
│   │   └── templates/
│   │       ├── php.ini
│   │       └── supervisord.conf
│   └── .dockerignore
├── .env.example               # Environment variable template
├── README.md                  # This file
├── mautic/                    # Persistent data (auto-created)
│   ├── config/               # Mautic configuration
│   ├── logs/                 # Application logs
│   └── media/                # Uploaded files
│       ├── files/
│       └── images/
├── themes/                    # Custom themes directory
├── plugins/                   # Custom plugins directory
└── cron/                      # Custom cron configurations (optional)
```

## Custom Themes

### Adding a Custom Theme

1. Create your theme in the `./themes/` directory:

```bash
mkdir -p themes/my-custom-theme
cd themes/my-custom-theme
# Add your theme files here
```

2. The theme will be automatically available via volume mount at `/var/www/html/docroot/themes/my-custom-theme`

3. Activate in Mautic UI: Settings > Themes > Select your theme

### Theme Directory Structure

```
themes/
└── my-custom-theme/
    ├── config/
    │   └── theme.php           # Theme configuration
    ├── html/
    │   ├── base.html.twig        # Base template
    │   ├── email/
    │   └── ...
    ├── assets/
    │   ├── css/
    │   ├── js/
    │   └── images/
    └── views/
        └── ...
```

## Custom Plugins

### Adding a Custom Plugin

1. Create your plugin in the `./plugins/` directory:

```bash
mkdir -p plugins/MyPluginBundle
cd plugins/MyPluginBundle
# Add your plugin files here
```

2. Clear the cache:

```bash
docker exec mautic_web php bin/console cache:clear
```

3. Reload plugins:

```bash
docker exec mautic_web php bin/console mautic:plugins:reload
```

4. Enable in Mautic UI: Plugins > Manage Plugins

### Plugin Directory Structure

```
plugins/
└── MyPluginBundle/
    ├── Config/
    │   └── config.php          # Plugin configuration
    ├── Controller/
    │   └── ...
    ├── Entity/
    │   └── ...
    ├── Form/
    │   └── ...
    ├── Integration/
    │   └── ...
    ├── Model/
    │   └── ...
    ├── Services/
    │   └── ...
    ├── Views/
    │   └── ...
    ├── MyPluginBundle.php        # Main plugin file
    └── composer.json             # Plugin composer file
```

## Environment Variables

### Coolify Auto-Generated Variables

Coolify automatically generates these secure credentials:

| Variable | Description |
|----------|-------------|
| `SERVICE_PASSWORD_64_MYSQLROOT` | MySQL root password |
| `SERVICE_PASSWORD_64_MYSQL` | MySQL user password |
| `SERVICE_USER_MYSQL` | MySQL username |
| `SERVICE_PASSWORD_64_RABBITMQ` | RabbitMQ password |
| `SERVICE_USER_RABBITMQ` | RabbitMQ username |
| `SERVICE_URL_MAUTIC_80` | Full URL for Mautic web service |

### Manual Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MYSQL_DATABASE` | `mautic` | Database name |
| `MAUTIC_RUN_MIGRATIONS` | `false` | Run migrations on startup |
| `MAUTIC_LOAD_TEST_DATA` | `false` | Load test data (development only) |
| `DOCKER_MAUTIC_WORKERS_CONSUME_EMAIL` | `2` | Email queue workers |
| `DOCKER_MAUTIC_WORKERS_CONSUME_HIT` | `2` | Hit tracking workers |
| `DOCKER_MAUTIC_WORKERS_CONSUME_FAILED` | `2` | Failed message workers |
| `DEBUG` | `false` | Enable debug output |

## Health Checks

All services include health checks:

| Service | Check | Interval | Timeout | Retries |
|---------|-------|----------|---------|---------|
| MySQL | `mysqladmin ping` | 10s | 5s | 5 |
| RabbitMQ | `rabbitmq-diagnostics -q ping` | 5s | 30s | 10 |
| mautic_web | `curl -f http://localhost` | 15s | 10s | 15 |

## Resource Limits

Production-ready resource constraints:

| Service | Memory Limit | CPU Limit |
|---------|-------------|-----------|
| MySQL | 1GB | 1.0 |
| RabbitMQ | 512MB | 0.5 |
| mautic_web | 1GB | 1.0 |
| mautic_cron | 512MB | 0.5 |
| mautic_worker | 512MB | 0.5 |

## Cron Jobs

The `mautic_cron` service automatically runs these essential cron jobs:

| Job | Schedule | Command |
|-----|----------|---------|
| Segments Update | Every minute | `mautic:segments:update` |
| Campaigns Rebuild | Every minute | `mautic:campaigns:rebuild` |
| Campaigns Trigger | Every minute | `mautic:campaigns:trigger` |
| Email Send | Every minute | `mautic:emails:send` |
| Import | Every 5 minutes | `mautic:import` |
| Broadcasts Send | Every minute | `mautic:broadcasts:send` |
| Messages Send | Every minute | `mautic:messages:send` |
| Webhooks Process | Every minute | `mautic:webhooks:process` |
| Reports Scheduler | Every minute | `mautic:reports:scheduler` |

## Upgrading Mautic

To upgrade Mautic to a new version:

1. Update the `MAUTIC_VERSION` build arg in `docker-compose.yml` or `Dockerfile`
2. In Coolify, trigger a redeploy with force rebuild
3. Containers will automatically apply database migrations
4. Verify health checks pass
5. Test critical functionality

## Backup and Restore

### Backup

```bash
# Backup database
docker exec mysql mysqldump -u root -p mautic > mautic-backup.sql

# Backup volumes
docker run --rm -v mautic-coolify-mautic-data:/data -v $(pwd):/backup \
    alpine tar czf backup/mautic-data.tar.gz /data
```

### Restore

```bash
# Restore database
docker exec -i mysql mysql -u root -p mautic < mautic-backup.sql

# Restore volumes
docker run --rm -v mautic-coolify-mautic-data:/data -v $(pwd):/backup \
    alpine tar xzf backup/mautic-data.tar.gz -C /
```

## Troubleshooting

### Check logs

```bash
# Mautic web logs
docker logs mautic_web

# Cron logs
docker logs mautic_cron

# Worker logs
docker logs mautic_worker

# Application logs
docker exec mautic_web tail -f /var/www/html/var/logs/mautic.log
```

### Check queue status

```bash
# Check RabbitMQ queues
docker exec rabbitmq rabbitmqctl list_queues

# Check worker processes
docker exec mautic_worker supervisorctl status
```

### Clear cache

```bash
docker exec mautic_web php bin/console cache:clear
docker exec mautic_web php bin/console mautic:cache:clear
```

## Security Considerations

- Database and RabbitMQ passwords are auto-generated by Coolify
- SSL/TLS handled by Coolify's Traefik reverse proxy
- PHP settings configured for production
- No sensitive data in docker-compose.yml (use env vars)
- All services run as non-root user (www-data) where possible

## Mautic 5.x vs 7.x Changes

| Aspect | Mautic 5.x | Mautic 7.x |
|--------|------------|------------|
| PHP Version | 8.0, 8.1, 8.2, 8.3 | 8.3, 8.4 |
| Symfony Version | 5.x/6.x | 7.3 |
| Asset Management | Requires npm/node | Symfony AssetMapper - no npm required |
| Config Path | `/var/www/html/config` | `/var/www/html/config` - unchanged |
| Docroot | `/var/www/html/docroot` | `/var/www/html/docroot` - unchanged |

## Support

- [Mautic Documentation](https://docs.mautic.org/)
- [Mautic Forums](https://forum.mautic.org/)
- [Coolify Documentation](https://coolify.io/docs/)
- [Mautic Docker Repository](https://github.com/mautic/docker-mautic)
