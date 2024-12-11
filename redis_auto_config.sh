#!/bin/bash

# Auto Redis Installation and Configuration Script
# Author: Manouchehr Hashemloo
# Description: This script installs Redis, configures it based on server resources and workload type, and installs/configures the Redis module for all PHP versions on the server.

# Backup existing Redis configuration
if [ -f "/etc/redis/redis.conf" ]; then
  echo "Creating backup of Redis configuration..."
  cp /etc/redis/redis.conf /etc/redis/redis.conf.bak
  echo "Backup of Redis configuration created at /etc/redis/redis.conf.bak"
fi

# Backup existing PHP configuration files
PHP_BACKUP_DIR="/root/php_ini_backups"
echo "Creating backup directory for PHP configurations at $PHP_BACKUP_DIR..."
mkdir -p "$PHP_BACKUP_DIR"
cp /opt/cpanel/ea-php*/root/etc/php.d/*.ini "$PHP_BACKUP_DIR" 2>/dev/null
cp /opt/alt/php*/etc/php.d/*.ini "$PHP_BACKUP_DIR" 2>/dev/null
echo "PHP configuration files backed up to $PHP_BACKUP_DIR"

# Check if Redis is installed
if ! command -v redis-server &> /dev/null; then
  echo "Redis is not installed. Installing Redis..."
  if [ -x "$(command -v yum)" ]; then
    yum install -y redis
  elif [ -x "$(command -v apt)" ]; then
    apt update && apt install -y redis
  else
    echo "Unsupported package manager. Please install Redis manually."
    exit 1
  fi
else
  echo "Redis is already installed."
fi

# Detect control panel
if [ -d "/usr/local/cpanel" ]; then
  CONTROL_PANEL="cPanel"
elif [ -d "/usr/local/directadmin" ]; then
  CONTROL_PANEL="DirectAdmin"
else
  CONTROL_PANEL="None"
fi

echo "Detected Control Panel: $CONTROL_PANEL"

# Dynamically locate Redis configuration file
REDIS_CONF_PATH=$(find /etc -type f -name "redis.conf" 2>/dev/null | head -n 1)

if [ -z "$REDIS_CONF_PATH" ]; then
  echo "Redis configuration file not found. Exiting."
  exit 1
else
  echo "Redis configuration file found at: $REDIS_CONF_PATH"
fi

# Prompt admin for workload type
read -p "Enter the server workload type (1 for Shared Hosting, 2 for High-Traffic Website, 3 for E-commerce): " workload_type

# Detect server resources
RAM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
CPU_CORES=$(nproc)

# Determine Redis configuration values based on workload type
if [ "$workload_type" == "1" ]; then
  MAX_MEMORY=$((RAM_TOTAL / 4))M
  MAX_CLIENTS=100
  SAVE_SETTINGS="save 900 1\nsave 300 10\nsave 60 10000"
elif [ "$workload_type" == "2" ]; then
  MAX_MEMORY=$((RAM_TOTAL / 2))M
  MAX_CLIENTS=500
  SAVE_SETTINGS="save 300 1\nsave 60 1000\nsave 15 10000"
elif [ "$workload_type" == "3" ]; then
  MAX_MEMORY=$((RAM_TOTAL / 2))M
  MAX_CLIENTS=1000
  SAVE_SETTINGS="save 60 1\nsave 15 1000\nsave 5 10000"
else
  echo "Invalid workload type. Exiting."
  exit 1
fi

# Redis configuration template
REDIS_CONF_TEMPLATE=$(cat << EOF
# General settings
daemonize yes
port 6379
bind 127.0.0.1

# Memory settings
maxmemory $MAX_MEMORY
maxmemory-policy allkeys-lru

# Connection settings
maxclients $MAX_CLIENTS

# Save settings
$SAVE_SETTINGS

# Log settings
loglevel notice
logfile /var/log/redis/redis.log

# Persistent storage
dir /var/lib/redis
dbfilename dump.rdb
EOF
)

# Apply Redis configuration
if [ -w "$REDIS_CONF_PATH" ]; then
  echo "Applying Redis configuration..."
  echo "$REDIS_CONF_TEMPLATE" > "$REDIS_CONF_PATH"
  echo "Redis configuration applied to $REDIS_CONF_PATH"
else
  echo "Error: Cannot write to $REDIS_CONF_PATH. Check permissions."
  exit 1
fi

# Restart Redis service
if systemctl is-active --quiet redis; then
  echo "Restarting Redis service..."
  systemctl restart redis
else
  echo "Starting Redis service..."
  systemctl start redis
fi

# Install and configure Redis module for all PHP versions
for php_ini_dir in $(find /opt/alt/php*/etc /opt/cpanel/ea-php*/root/etc -type d -name php.d 2>/dev/null); do
  PHP_BIN="$(dirname $php_ini_dir)/bin/php"
  PHP_PECL_BIN="$(dirname $php_ini_dir)/bin/pecl"

  if [ -x "$PHP_BIN" ]; then
    # Check if Redis module is already installed
    if ! "$PHP_BIN" -m | grep -q "^redis$"; then
      echo "Redis module not found for PHP in $php_ini_dir. Installing..."
      if [ -x "$PHP_PECL_BIN" ]; then
        echo no | "$PHP_PECL_BIN" install redis
      else
        echo "PECL not found for PHP in $php_ini_dir. Skipping Redis module installation."
        continue
      fi
    else
      echo "Redis module already installed for PHP in $php_ini_dir."
    fi

    # Configure Redis module in php.ini
    REDIS_INI=$(find "$php_ini_dir" -type f -name "*redis.ini" 2>/dev/null | head -n 1)
    if [ -z "$REDIS_INI" ]; then
      REDIS_INI="$php_ini_dir/redis.ini"
    fi
    echo "extension=redis.so" > "$REDIS_INI"
    echo "session.save_handler = redis" >> "$REDIS_INI"
    echo "session.save_path = \"tcp://127.0.0.1:6379\"" >> "$REDIS_INI"
    echo "Redis module configured in $REDIS_INI"
  else
    echo "PHP binary not found for PHP in $php_ini_dir. Skipping."
  fi
done

# Completion message
echo "Redis installation and configuration completed successfully."
