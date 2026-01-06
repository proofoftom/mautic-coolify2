# Mautic 5.x to 7.x Breaking Changes for Docker Deployments

This document outlines the breaking changes and migration considerations when upgrading from Mautic 5.x to Mautic 7.x in a Docker environment.

## Overview

Mautic 7.x represents a major upgrade with significant changes to the underlying technology stack:

- **PHP Version**: 8.3, 8.4 (was 8.0-8.3 in 5.x)
- **Symfony Version**: 7.3 (was 5.x/6.x in 5.x)
- **Asset Management**: Symfony AssetMapper (no npm required, was npm in 5.x)

## PHP Version Changes

### Mautic 5.x
- Supported: PHP 8.0, 8.1, 8.2, 8.3
- Recommended: PHP 8.1+

### Mautic 7.x
- Supported: PHP 8.3, 8.4
- Recommended: PHP 8.4

### Impact
- **Docker Base Image**: Change from `php:8.3-apache-bookworm` to `php:8.4-apache-bookworm`
- **Extensions**: All PHP extensions remain compatible
- **Configuration**: PHP settings remain unchanged

### Migration Steps
1. Update Dockerfile base image
2. Rebuild Docker image
3. Test all PHP-dependent functionality

## Symfony Version Changes

### Mautic 5.x
- Symfony 5.x or 6.x

### Mautic 7.x
- Symfony 7.3

### Impact
- **Bundle Compatibility**: Some Symfony bundles may have breaking changes
- **Console Commands**: Command signatures may have changed
- **Service Container**: Service definitions may need updates

### Migration Steps
1. Review Symfony 7 upgrade guide
2. Update custom bundles/plugins for Symfony 7 compatibility
3. Test console commands
4. Verify service injection in custom code

## Asset Management Changes

### Mautic 5.x
- Required npm/node for asset building
- Assets built during Docker image build
- `npm install && npm run build` process

### Mautic 7.x
- **No npm required** - uses Symfony AssetMapper
- Assets built via PHP during Docker image build
- `php bin/console mautic:assets:generate` command

### Impact
- **Dockerfile**: No longer needs Node.js installation
- **Build Time**: Potentially faster (no npm install)
- **Custom Assets**: Asset compilation process changed

### Migration Steps
1. Remove npm/node installation from Dockerfile
2. Use `php bin/console mautic:assets:generate` instead of npm build
3. Clear asset cache: `php bin/console mautic:cache:clear`

## Docker Image Changes

### Mautic 5.x
- Official image: `mautic/mautic:5-apache`
- Multi-stage build with builder/runtime stages
- Entrypoint scripts for web/cron/worker roles

### Mautic 7.x
- **No official image exists** (as of current release)
- Custom Dockerfile required based on official structure
- Same entrypoint script architecture

### Impact
- **Image Source**: Must build from source using custom Dockerfile
- **Build Time**: Longer initial build (Composer install)
- **Image Size**: Similar to 5.x images

### Migration Steps
1. Use custom Dockerfile provided in this repository
2. Build image locally or in CI/CD pipeline
3. Tag image appropriately for version tracking

## Database Changes

### Schema Changes
- Database migrations are applied automatically on startup when `MAUTIC_RUN_MIGRATIONS=true`
- Review migration files in Mautic 7.x source for breaking schema changes

### Data Migration
- Most data is compatible between versions
- Backup database before upgrading

### Migration Steps
1. Backup database: `docker exec mysql mysqldump -u root -p mautic > backup.sql`
2. Set `MAUTIC_RUN_MIGRATIONS=true` for first deployment
3. Verify data integrity after migration

## Configuration Changes

### Environment Variables
All core environment variables remain compatible:

| Variable | Mautic 5.x | Mautic 7.x | Changed? |
|----------|------------|------------|---------|
| `MAUTIC_DB_HOST` | Yes | Yes | No |
| `MAUTIC_DB_USER` | Yes | Yes | No |
| `MAUTIC_DB_PASSWORD` | Yes | Yes | No |
| `MAUTIC_DB_DATABASE` | Yes | Yes | No |
| `MAUTIC_MESSENGER_DSN_EMAIL` | Yes | Yes | No |
| `MAUTIC_MESSENGER_DSN_HIT` | Yes | Yes | No |
| `DOCKER_MAUTIC_ROLE` | Yes | Yes | No |

### New Variables
No new required environment variables in Mautic 7.x.

## Plugin and Theme Changes

### Plugin Compatibility
- Plugins must be updated for Mautic 7.x compatibility
- Check plugin documentation for version requirements
- Test all plugins after upgrade

### Theme Compatibility
- Themes using standard Twig templates should work
- Themes with custom asset compilation may need updates
- Test all themes after upgrade

## API Changes

### Breaking API Changes
- Review Mautic 7.x changelog for API changes
- Update any custom API integrations
- Test API endpoints thoroughly

## Cron Job Changes

### Unchanged
- All cron job commands remain the same
- Schedules remain unchanged
- No action required for cron configuration

## Known Issues and Workarounds

### Issue 1: Asset Compilation
**Problem**: Custom themes with npm-based asset compilation

**Solution**: Convert to Symfony AssetMapper or use build process outside container

### Issue 2: Plugin Compatibility
**Problem**: Third-party plugins not yet updated for Mautic 7.x

**Solution**: Contact plugin maintainers or fork and update

### Issue 3: Custom Console Commands
**Problem**: Custom commands may fail with Symfony 7

**Solution**: Update command signatures to match Symfony 7 patterns

## Upgrade Checklist

Before upgrading from Mautic 5.x to 7.x:

- [ ] Backup database
- [ ] Backup volumes (config, media, themes, plugins)
- [ ] Review plugin compatibility
- [ ] Update custom plugins for Mautic 7.x
- [ ] Review theme compatibility
- [ ] Test theme asset compilation
- [ ] Review Symfony 7 breaking changes
- [ ] Update custom code for Symfony 7
- [ ] Test in staging environment first
- [ ] Plan rollback procedure

## Rollback Procedure

If issues occur after upgrade:

1. Stop all containers
2. Restore database from backup
3. Restore volumes from backup
4. Revert docker-compose.yml to Mautic 5.x image
5. Restart containers

## Additional Resources

- [Mautic 7.x Release Notes](https://github.com/mautic/mautic/releases)
- [Symfony 7 Upgrade Guide](https://symfony.com/doc/current/upgrade.html)
- [Mautic Documentation](https://docs.mautic.org/)
- [Mautic Forums](https://forum.mautic.org/)
