#!/bin/bash

# Auto Redis Configuration Script
# Author: Manouchehr Hashemloo
# Description: This script installs Redis if not already installed, configures it based on server resources and workload type, and integrates with PHP versions if applicable.

# Check if Redis is installed
if ! command -v redis-server &> /dev/null; then
  echo "Redis is not installed. Installing Redis..."
  if [ -x "$(command -v yum)" ]; then
    yum install -y redis
  elif [ -x "$(command -v apt)" ]; then
    apt update && apt install -y redis
  else
    echo "Unsupported package manager. Install Redis manually."
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
  CONTROL_PANEL="Unknown"
fi

echo "Detected Control Panel: $CONTROL_PANEL"

# Prompt admin for server workload type
read -p "Enter the server workload type (1 for Shared Hosting, 2 for High-Traffic Website, 3 for E-commerce): " workload_type

# Detect server resources
RAM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
CPU_CORES=$(nproc)

# Determine Redis configuration values based on workload type and server resources
if [ "$workload_type" == "1" ]; then
  # Shared Hosting
  MAX_MEMORY=$((RAM_TOTAL / 4))M
  MAX_CLIENTS=100
  SAVE_SETTINGS="save 900 1\nsave 300 10\nsave 60 10000"
elif [ "$workload_type" == "2" ]; then
  # High-Traffic Website
  MAX_MEMORY=$((RAM_TOTAL / 2))M
  MAX_CLIENTS=500
  SAVE_SETTINGS="save 300 1\nsave 60 1000\nsave 15 10000"
elif [ "$workload_type" == "3" ]; then
  # E-commerce
  MAX_MEMORY=$((RAM_TOTAL / 2))M
  MAX_CLIENTS=1000
  SAVE_SETTINGS="save 60 1\nsave 15 1000\nsave 5 10000"
else
  echo "Invalid workload type. Exiting."
  exit 1
fi

# Redis configuration template
REDIS_CONF_TEMPLATE="""
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
"""

# Apply configuration
REDIS_CONF_PATH="/etc/redis/redis.conf"
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

# Detect installed PHP versions and configure Redis
for php_dir in /opt/alt/php*/etc /opt/cpanel/ea-php*/root/etc; do
  if [ -d "$php_dir" ]; then
    for php_ini in $(find "$php_dir" -name 'php.ini'); do
      echo "Configuring Redis session handler for $(basename $(dirname $php_ini))..."
      if ! grep -q '^session.save_handler = redis' "$php_ini"; then
        echo "session.save_handler = redis" >> "$php_ini"
        echo "session.save_path = \"tcp://127.0.0.1:6379\"" >> "$php_ini"
        echo "Redis session handler configured for $(basename $(dirname $php_ini))"
      else
        echo "Redis session handler already configured for $(basename $(dirname $php_ini))"
      fi
    done
  fi
done

# Completion message
echo "Redis installation and configuration completed successfully."
