# Mautic 7.x Docker Deployment for Coolify

## Overview

This plan outlines the design for a comprehensive Docker deployment configuration for Mautic 7.x optimized for Coolify, based on analysis of the official Mautic Docker repository and the existing Coolify Mautic 5 template.

## Architecture

```mermaid
graph TB
    subgraph Coolify Platform
        Traefik[Traefik Reverse Proxy]
    end
    
    subgraph Mautic Stack
        Web[mautic_web<br/>Apache + PHP 8.4<br/>Port 80]
        Cron[mautic_cron<br/>Background Tasks]
        Worker[mautic_worker<br/>Queue Consumer]
        MySQL[(MySQL 8.0<br/>Database)]
        RabbitMQ[RabbitMQ 3<br/>Message Broker]
    end
    
    subgraph Persistent Volumes
        Config[config/]
        Logs[var/logs/]
        Media[docroot/media/]
        Themes[docroot/themes/]
        Plugins[docroot/plugins/]
        DBData[mysql-data/]
        RMQData[rabbitmq-data/]
    end
    
    Traefik -->|HTTPS| Web
    Web --> MySQL
    Web --> RabbitMQ
    Cron --> MySQL
    Worker --> MySQL
    Worker --> RabbitMQ
    
    Web --> Config
    Web --> Logs
    Web --> Media
    Web --> Themes
    Web --> Plugins
    
    Cron --> Config
    Cron --> Logs
    
    Worker --> Config
    Worker --> Logs
    
    MySQL --> DBData
    RabbitMQ --> RMQData
```

## Key Design Decisions

### 1. Base Image Strategy

**Decision**: Build a custom Dockerfile from scratch based on the official Mautic Docker repository structure.

**Rationale**:
- **No official Mautic 7 Docker image exists yet** (latest is `mautic/mautic:6.0.7-20251229-apache`)
- Mautic 7 is currently in Release Candidate status
- We will replicate the official Dockerfile structure from [mautic/docker-mautic](https://github.com/mautic/docker-mautic) but target Mautic 7.x
- This gives us full control over PHP version, entrypoint scripts, and build process

**Build Approach**:
```
Base Image: php:8.4-apache-bookworm
Mautic Version: 7.x-dev (or specific 7.0.0 tag when released)
Build Method: composer create-project mautic/recommended-project:7.x-dev
```

**Key Components to Replicate**:
1. Multi-stage build (builder + runtime)
2. PHP extensions installation (intl, gd, imap, opcache, amqp, etc.)
3. Entrypoint scripts for mautic_web, mautic_cron, mautic_worker roles
4. Supervisor configuration for worker processes
5. Apache document root configuration

### 1.1 Custom Dockerfile Structure

Since no official Mautic 7 Docker image exists, we will build a custom Dockerfile based on the official Mautic Docker repository structure.

**Project Structure for Custom Build**:
```
docker/
├── Dockerfile              # Main multi-stage Dockerfile
├── common/
│   ├── docker-entrypoint.sh
│   ├── entrypoint_mautic_web.sh
│   ├── entrypoint_mautic_cron.sh
│   ├── entrypoint_mautic_worker.sh
│   ├── templates/
│   │   ├── php.ini
│   │   └── supervisord.conf
│   └── startup/
└── .dockerignore
```

**Multi-Stage Build Process**:
```mermaid
graph LR
    A[php:8.4-apache-bookworm] --> B[Builder Stage]
    B --> C[Runtime Stage]
    
    B -->|Install PHP extensions| D[Extensions]
    B -->|Composer create-project| E[Mautic 7.x]
    B -->|Build assets| F[Asset generation]
    
    C -->|Copy extensions| D
    C -->|Copy Mautic| E
    C -->|Copy entrypoint scripts| G[Scripts]
    C -->|Copy supervisord| H[Supervisor]
```

**Builder Stage Tasks**:
1. Install PHP extensions: intl, mbstring, mysqli, curl, pdo_mysql, zip, bcmath, sockets, exif, amqp, gd, imap, opcache
2. Install Composer
3. Create Mautic project: `composer create-project mautic/recommended-project:7.x-dev`
4. Build web assets: `npm install && php bin/console mautic:assets:generate`

**Runtime Stage Tasks**:
1. Copy PHP extensions from builder
2. Copy Mautic application from builder
3. Copy entrypoint scripts
4. Copy supervisord configuration
5. Install runtime dependencies: cron, git, mariadb-client, supervisor
6. Configure Apache document root to `/var/www/html/docroot`
7. Set proper ownership for www-data

**Entrypoint Scripts**:
- `docker-entrypoint.sh`: Main entrypoint that routes to role-specific scripts
- `entrypoint_mautic_web.sh`: Runs Apache web server, handles migrations
- `entrypoint_mautic_cron.sh`: Runs cron daemon for scheduled tasks
- `entrypoint_mautic_worker.sh`: Runs supervisord for queue consumers

### 2. Mautic 5.x vs 7.x Breaking Changes

| Aspect | Mautic 5.x | Mautic 7.x |
|--------|------------|------------|
| PHP Version | 8.0, 8.1, 8.2, 8.3 | 8.3, 8.4 |
| Symfony Version | 5.x/6.x | 7.3 |
| Asset Management | Requires npm/node | Symfony AssetMapper - no npm required |
| Messenger DSN | `amqp://` or `doctrine://` | `doctrine://default` preferred |
| Config Path | `/var/www/html/config` | `/var/www/html/config` - unchanged |
| Docroot | `/var/www/html/docroot` | `/var/www/html/docroot` - unchanged |

### 3. Message Queue Strategy

**Decision**: Use RabbitMQ for message queuing (based on official Mautic Docker example).

**Rationale**:
- Better scalability for high-volume email campaigns
- Asynchronous processing improves web interface responsiveness
- Decouples message processing from database load
- Standard AMQP protocol for reliability
- Official Mautic Docker team recommended approach

**Configuration**:
```
MAUTIC_MESSENGER_DSN_EMAIL=amqp://${RABBITMQ_DEFAULT_USER}:${RABBITMQ_DEFAULT_PASS}@rabbitmq:5672/${RABBITMQ_DEFAULT_VHOST}/messages
MAUTIC_MESSENGER_DSN_HIT=amqp://${RABBITMQ_DEFAULT_USER}:${RABBITMQ_DEFAULT_PASS}@rabbitmq:5672/${RABBITMQ_DEFAULT_VHOST}/messages
```

**RabbitMQ Service**:
- Image: `rabbitmq:3`
- Volume: `rabbitmq-data:/var/lib/rabbitmq`
- Environment variables for user, password, and vhost

### 4. Service Roles

The Mautic Docker image supports three roles via `DOCKER_MAUTIC_ROLE`:

1. **mautic_web**: Main web application server
   - Serves HTTP requests
   - Handles user interface
   - Runs migrations on startup when enabled

2. **mautic_cron**: Scheduled task runner
   - Executes cron jobs for segments, campaigns, emails
   - Runs maintenance tasks
   - Depends on mautic_web being healthy

3. **mautic_worker**: Queue consumer
   - Processes async messages from RabbitMQ
   - Handles email sending, hit tracking
   - Configurable worker count per queue type
   - `DOCKER_MAUTIC_WORKERS_CONSUME_EMAIL` - workers for email queue
   - `DOCKER_MAUTIC_WORKERS_CONSUME_HIT` - workers for hit tracking queue
   - `DOCKER_MAUTIC_WORKERS_CONSUME_FAILED` - workers for failed messages

### 5. Volume Mount Strategy

```mermaid
graph LR
    subgraph Host/Coolify Storage
        H1[./mautic/config]
        H2[./mautic/logs]
        H3[./mautic/media/files]
        H4[./mautic/media/images]
        H5[./themes/custom-theme]
        H6[./plugins/custom-plugin]
        H7[mysql-data volume]
        H8[rabbitmq-data volume]
    end
    
    subgraph Container Paths
        C1[/var/www/html/config]
        C2[/var/www/html/var/logs]
        C3[/var/www/html/docroot/media/files]
        C4[/var/www/html/docroot/media/images]
        C5[/var/www/html/docroot/themes/custom-theme]
        C6[/var/www/html/docroot/plugins/custom-plugin]
        C7[/var/lib/mysql]
        C8[/var/lib/rabbitmq]
    end
    
    H1 --> C1
    H2 --> C2
    H3 --> C3
    H4 --> C4
    H5 --> C5
    H6 --> C6
    H7 --> C7
    H8 --> C8
```

### 6. Coolify-Specific Configuration

**Environment Variable Magic**:
- `SERVICE_FQDN_MAUTIC_80`: Auto-generates FQDN for the main web service
- `SERVICE_URL_MAUTIC`: Full URL with protocol
- `SERVICE_PASSWORD_64_*`: Auto-generated 64-char passwords
- `SERVICE_USER_*`: Auto-generated usernames

**Labels for Traefik**:
```yaml
labels:
  - coolify.managed=true
  - traefik.enable=true
```

### 7. Health Checks

| Service | Health Check | Interval | Timeout | Retries |
|---------|-------------|----------|---------|---------|
| MySQL | `mysqladmin ping` | 5s | 5s | 10 |
| RabbitMQ | `rabbitmq-diagnostics -q ping` | 5s | 30s | 10 |
| mautic_web | `curl http://localhost` | 5s | 5s | 100 |
| mautic_cron | depends on mautic_web healthy | - | - | - |
| mautic_worker | depends on mautic_web healthy | - | - | - |

### 8. Resource Constraints

Recommended production constraints:

| Service | Memory Limit | CPU Limit |
|---------|-------------|-----------|
| MySQL | 1GB | 1.0 |
| RabbitMQ | 512MB | 0.5 |
| mautic_web | 512MB-1GB | 1.0 |
| mautic_cron | 512MB | 0.5 |
| mautic_worker | 512MB | 0.5 |

## Project Structure

```
mautic-coolify/
├── docker-compose.yml          # Main Coolify compose file
├── docker/                     # Custom Docker build files
│   ├── Dockerfile              # Multi-stage Dockerfile for Mautic 7.x
│   ├── common/
│   │   ├── docker-entrypoint.sh
│   │   ├── entrypoint_mautic_web.sh
│   │   ├── entrypoint_mautic_cron.sh
│   │   ├── entrypoint_mautic_worker.sh
│   │   ├── templates/
│   │   │   ├── php.ini
│   │   │   └── supervisord.conf
│   │   └── startup/
│   └── .dockerignore
├── .env.example               # Environment variable template
├── README.md                  # Deployment documentation
├── mautic/                    # Persistent data (auto-created)
│   ├── config/               # Mautic configuration
│   ├── logs/                 # Application logs
│   └── media/                # Uploaded files
│       ├── files/
│       └── images/
├── themes/                    # Custom themes directory
│   └── .gitkeep
├── plugins/                   # Custom plugins directory
│   └── .gitkeep
└── cron/                      # Custom cron configurations (optional)
    └── .gitkeep
```

## Cron Jobs

The `mautic_cron` role automatically runs these essential cron jobs:

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

## Database Migrations

**Strategy**: Enable automatic migrations on web container startup.

```yaml
environment:
  - DOCKER_MAUTIC_RUN_MIGRATIONS=true
```

This ensures:
- Fresh installations are properly initialized
- Version upgrades automatically apply schema changes
- No manual intervention required for updates

## Custom Themes Workflow

1. Create theme in `./themes/your-theme-name/` directory
2. Theme is automatically available via volume mount
3. Activate in Mautic UI under Settings > Themes
4. Changes persist across container restarts/updates

## Custom Plugins Workflow

1. Create plugin in `./plugins/YourPluginBundle/` directory
2. Plugin is automatically available via volume mount
3. Clear cache: `docker exec mautic_web php bin/console cache:clear`
4. Install: `docker exec mautic_web php bin/console mautic:plugins:reload`

## Upgrade Path

To upgrade Mautic version:

1. Update image tag in `docker-compose.yml` or `Dockerfile`
2. Pull new images: `docker compose pull`
3. Restart with migration: containers will auto-migrate
4. Verify health checks pass
5. Test critical functionality

## Security Considerations

- Database passwords auto-generated by Coolify
- SSL/TLS handled by Traefik reverse proxy
- PHP settings configured for production
- No sensitive data in docker-compose.yml (use env vars)
