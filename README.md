# Redis Auto Configuration Script

## Overview
This script automates the installation and configuration of **Redis** on a Linux server. It detects server resources, allows customization based on workload type (Shared Hosting, High-Traffic Website, or E-commerce), and integrates Redis with installed PHP versions.

## Features
- **Automatic Installation**: Installs Redis if it is not already installed.
- **Dynamic Configuration**: Adjusts Redis settings based on server RAM and workload type.
- **PHP Integration**: Configures Redis as the session handler for all detected PHP versions.
- **Control Panel Detection**: Detects cPanel or DirectAdmin to apply specific configurations.

## Workload Types
1. **Shared Hosting**:
   - Lower memory allocation.
   - Optimized for multi-tenant environments.

2. **High-Traffic Website**:
   - Increased memory and client limits for better performance.

3. **E-commerce**:
   - Maximum memory allocation and aggressive persistence settings for stability and performance.

## Requirements
- Linux-based server
- Root privileges
- Supported package managers: `yum` or `apt`

## How to Use

### Step 1: Download the Script
Save the script as `redis_auto_config.sh`.

### Step 2: Make the Script Executable
```bash
chmod +x redis_auto_config.sh
```

### Step 3: Run the Script
Execute the script with root privileges:
```bash
sudo ./redis_auto_config.sh
```

### Step 4: Follow Prompts
The script will prompt you to select the workload type:
- Enter `1` for Shared Hosting.
- Enter `2` for High-Traffic Website.
- Enter `3` for E-commerce.

### Step 5: Verify Installation
- Ensure Redis is running:
  ```bash
  systemctl status redis
  ```
- Check PHP integration by verifying session settings in the `php.ini` files:
  ```bash
  grep session.save_handler /path/to/php.ini
  ```

## Configuration Details

### Redis Configuration
The script dynamically applies the following settings:

| Setting                 | Shared Hosting | High-Traffic Website | E-commerce |
|-------------------------|----------------|-----------------------|------------|
| `maxmemory`            | 25% of RAM    | 50% of RAM           | 50% of RAM |
| `maxclients`           | 100           | 500                   | 1000       |
| `save` (persistence)   | Longer periods | Medium periods        | Aggressive |

### PHP Integration
The script appends the following settings to all detected `php.ini` files:
```ini
session.save_handler = redis
session.save_path = "tcp://127.0.0.1:6379"
```

## Logs
Redis logs are stored at `/var/log/redis/redis.log`.

## Troubleshooting
- **Permission Issues**: Ensure the script is run with root privileges.
- **Unsupported Control Panel**: The script supports cPanel and DirectAdmin. For others, manual adjustments may be required.
- **Redis Service Not Starting**: Check the Redis configuration file at `/etc/redis/redis.conf` for syntax errors.

## Contributions
Feel free to suggest improvements or submit pull requests to enhance this script.


