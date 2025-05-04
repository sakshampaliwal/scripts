#!/bin/bash

# Function to validate domain name
validate_domain() {
    local domain=$1
}

# Function to validate port number
validate_port() {
    local port=$1
}

# Function to validate directory
validate_directory() {
    local dir
    while true; do
        read -p "Enter the full path to your static files directory: " dir
        if [ -d "$dir" ]; then
            echo "$dir"
            break
        else
            echo "Directory does not exist. Please enter a valid directory path"
        fi
    done
}

# Update system and install Apache
echo "Updating system and installing Apache..."
sudo apt update && sudo apt upgrade -y
sudo apt install apache2 -y

# Enable required Apache modules
echo "Enabling required Apache modules..."
sudo a2enmod headers
sudo a2enmod proxy
sudo a2enmod proxy_http

# Start and enable Apache
sudo systemctl start apache2
sudo systemctl enable apache2
sudo systemctl status apache2

# Configure firewall
echo "Configuring firewall..."
sudo ufw allow 'Apache'
sudo ufw enable
sudo ufw status

# Get site name
read -p "Enter your site domain (like xyz.fulldomain.com): " domain
validate_domain "$domain"

# Ask for website type
while true; do
    echo "Select website type:"
    echo "1) Static website"
    echo "2) Reverse proxy server"
    read -p "Enter choice (1 or 2): " website_type
    if [ "$website_type" = "1" ] || [ "$website_type" = "2" ]; then
        break
    else
        echo "Invalid choice. Please enter 1 or 2."
    fi
done

# Initialize virtual host configuration
vhost_config="<VirtualHost *:80>
    ServerName $domain
    ServerAdmin admin@$domain

    # Logging
    ErrorLog \${APACHE_LOG_DIR}/reverse-proxy-error.log
    CustomLog \${APACHE_LOG_DIR}/reverse-proxy-access.log combined

    # Security Headers
    Header always set X-Frame-Options \"SAMEORIGIN\"
    Header always set X-Content-Type-Options \"nosniff\"
    Header always set X-XSS-Protection \"1; mode=block\"
"

if [ "$website_type" = "1" ]; then
    # Static website configuration
    read -p "Enter the full path to your static files directory: " static_dir
    validate_directory "$static_dir"

    # Create website directory
    sudo mkdir -p /var/www/$domain
    sudo cp -r "$static_dir"/* /var/www/$domain/
    sudo chown -R www-data:www-data /var/www/$domain
    sudo chmod -R 755 /var/www/$domain

    # Add static serving configuration
    vhost_config+="
    DocumentRoot /var/www/$domain
    <Directory /var/www/$domain>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    "
elif [ "$website_type" = "2" ]; then
    # Reverse proxy configuration
    read -p "Enter the port number for reverse proxy (e.g., 8090): " proxy_port
    validate_port "$proxy_port"

    # Add reverse proxy configuration
    vhost_config+="
    # Timeout settings
    ProxyTimeout 60

    # Reverse Proxy Rules
    ProxyPass \"/\" \"http://localhost:$proxy_port/\"
    ProxyPassReverse \"/\" \"http://localhost:$proxy_port/\"
    "
else
    echo "Invalid choice. Exiting..."
    exit 1
fi

# Complete virtual host configuration
vhost_config+="
    # Restrict default filesystem access
    <Directory />
        Require all denied
    </Directory>
</VirtualHost>"

# Write virtual host configuration
echo "$vhost_config" | sudo tee /etc/apache2/sites-available/$domain.conf

# Enable site and disable default
sudo a2ensite $domain.conf
sudo a2dissite 000-default.conf
sudo apache2ctl configtest
if [ $? -eq 0 ]; then
    sudo systemctl reload apache2
else
    echo "Configuration test failed. Please check /etc/apache2/sites-available/$domain.conf"
    echo "You can also check error logs with: sudo tail -f /var/log/apache2/error.log"
    exit 1
fi

# SSL configuration
read -p "Do you want to configure SSL? (y/n): " ssl_choice
if [ "$ssl_choice" = "y" ] || [ "$ssl_choice" = "Y" ]; then
    echo "Installing Certbot and configuring SSL..."
    sudo apt install certbot python3-certbot-apache -y
    sudo ufw allow 'Apache Full'
    sudo ufw delete allow 'Apache'
    sudo certbot --apache -d $domain
    sudo certbot renew --dry-run
    sudo apache2ctl configtest
    if [ $? -eq 0 ]; then
        sudo systemctl reload apache2
    else
        echo "SSL configuration test failed. Please check the configuration."
        echo "You can check error logs with: sudo tail -f /var/log/apache2/error.log"
        exit 1
    fi
fi

echo "Setup complete! You can check Apache error logs with:"
echo "sudo tail -f /var/log/apache2/error.log"
