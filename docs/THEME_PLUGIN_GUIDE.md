# Custom Themes and Plugins Guide

This guide explains how to add and manage custom themes and plugins in the Mautic 7.x Coolify deployment.

## Overview

Themes and plugins are mounted as Docker volumes, allowing them to persist across container updates and be managed outside the container.

## Custom Themes

### Adding a Custom Theme

#### Step 1: Create Theme Directory

Create your theme in the `./themes/` directory:

```bash
mkdir -p themes/my-custom-theme
cd themes/my-custom-theme
```

#### Step 2: Theme Directory Structure

A Mautic theme follows this structure:

```
themes/
└── my-custom-theme/
    ├── Config/
    │   └── config.php           # Theme configuration
    ├── html/
    │   ├── base.html.twig        # Base template
    │   ├── email/
    │   │   └── base.html.twig    # Email base template
    │   ├── slots/
    │   │   └── ...
    │   └── ...
    ├── assets/
    │   ├── css/
    │   │   └── app.css
    │   ├── js/
    │   │   └── app.js
    │   └── images/
    │       └── logo.png
    └── views/
        └── ...
```

#### Step 3: Theme Configuration

Create `Config/config.php`:

```php
<?php

return [
    'name' => 'My Custom Theme',
    'author' => 'Your Name',
    'version' => '1.0.0',
    'description' => 'A custom theme for Mautic 7.x',
];
```

#### Step 4: Base Template

Create `html/base.html.twig`:

```twig
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>{% block title %}Mautic{% endblock %}</title>
    {% block head %}{% endblock %}
</head>
<body>
    {% block body %}{% endblock %}
</body>
</html>
```

#### Step 5: Activate Theme

1. Access Mautic admin panel
2. Go to **Settings > Themes**
3. Select your theme from the dropdown
4. Click **Apply**

### Theme Development Tips

#### Asset Compilation

Mautic 7.x uses Symfony AssetMapper, so assets are compiled via PHP:

```bash
# Clear cache to rebuild assets
docker exec mautic_web php bin/console cache:clear
```

#### Template Inheritance

Extend the base template in your templates:

```twig
{% extends '@MyCustomTheme/base.html.twig' %}

{% block content %}
    <h1>My Custom Page</h1>
{% endblock %}
```

#### Custom Slots

Define custom slots in your theme:

```twig
{% block my_custom_slot %}
    <div class="custom-content">
        {% block my_custom_slot_content %}{% endblock %}
    </div>
{% endblock %}
```

## Custom Plugins

### Adding a Custom Plugin

#### Step 1: Create Plugin Directory

Create your plugin in the `./plugins/` directory:

```bash
mkdir -p plugins/MyPluginBundle
cd plugins/MyPluginBundle
```

#### Step 2: Plugin Directory Structure

A Mautic plugin follows this structure:

```
plugins/
└── MyPluginBundle/
    ├── Config/
    │   ├── config.php          # Plugin configuration
    │   └── permissions.php     # Plugin permissions
    ├── Controller/
    │   ├── ApiController.php
    │   └── PublicController.php
    ├── Entity/
    │   └── MyEntity.php
    ├── Form/
    │   └── MyType.php
    ├── Integration/
    │   └── MyIntegration.php
    ├── Model/
    │   └── MyModel.php
    ├── Services/
    │   └── MyService.php
    ├── Views/
    │   └── ...
    ├── Translations/
    │   └── en_US.ini
    ├── Assets/
    │   ├── css/
    │   └── ...
    ├── MyPluginBundle.php        # Main plugin file
    └── composer.json             # Plugin composer file
```

#### Step 3: Main Plugin File

Create `MyPluginBundle.php`:

```php
<?php

namespace Mautic\Plugin\MyPluginBundle;

use Symfony\Component\HttpKernel\Bundle\Bundle;

class MyPluginBundle extends Bundle
{
    public function boot()
    {
        // Boot logic here
    }
}
```

#### Step 4: Plugin Configuration

Create `Config/config.php`:

```php
<?php

return [
    'name' => 'My Plugin',
    'description' => 'A custom plugin for Mautic 7.x',
    'version' => '1.0.0',
    'author' => 'Your Name',
];
```

#### Step 5: Install Plugin

1. Clear the cache:

```bash
docker exec mautic_web php bin/console cache:clear
```

2. Reload plugins:

```bash
docker exec mautic_web php bin/console mautic:plugins:reload
```

3. Enable in Mautic UI: **Plugins > Manage Plugins**

### Plugin Development Tips

#### Database Migrations

Create migration files in the plugin:

```bash
# Create migration
docker exec mautic_web php bin/console doctrine:migrations:generate
```

#### Services

Register services in `config/services.php`:

```php
<?php

use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;

return function (ContainerConfigurator $configurator): void {
    $configurator->services()
        ->set(MyService::class)
        ->arg('%mautic.db_table_prefix%');
};
```

#### API Endpoints

Create API controllers:

```php
<?php

namespace Mautic\Plugin\MyPluginBundle\Controller;

use Mautic\ApiBundle\Controller\CommonApiController;
use Symfony\Component\HttpFoundation\Response;

class ApiController extends CommonApiController
{
    public function myAction(): Response
    {
        return $this->json(['message' => 'Hello from My Plugin']);
    }
}
```

## Troubleshooting

### Theme Not Showing

1. Verify theme directory structure is correct
2. Check `Config/config.php` exists and is valid
3. Clear cache: `docker exec mautic_web php bin/console cache:clear`
4. Check file permissions: `docker exec mautic_web ls -la /var/www/html/docroot/themes/`

### Plugin Not Loading

1. Verify `MyPluginBundle.php` exists and extends `Bundle`
2. Check `composer.json` is valid
3. Clear cache: `docker exec mautic_web php bin/console cache:clear`
4. Reload plugins: `docker exec mautic_web php bin/console mautic:plugins:reload`
5. Check logs: `docker logs mautic_web`

### Assets Not Compiling

1. Clear cache: `docker exec mautic_web php bin/console cache:clear`
2. Rebuild assets: `docker exec mautic_web php bin/console mautic:assets:generate`
3. Check asset directory permissions

## Best Practices

### Themes

1. Use Twig template inheritance
2. Follow Mautic's naming conventions
3. Keep assets organized by type
4. Use CSS variables for theming
5. Test across different browsers

### Plugins

1. Follow Symfony best practices
2. Use dependency injection
3. Write tests for your code
4. Document your API
5. Handle errors gracefully

## Resources

- [Mautic Theme Development](https://developer.mautic.org/themes/)
- [Mautic Plugin Development](https://developer.mautic.org/plugins/)
- [Symfony AssetMapper Documentation](https://symfony.com/doc/current/asset_mapper.html)
- [Twig Documentation](https://twig.symfony.com/doc/3.x/)
