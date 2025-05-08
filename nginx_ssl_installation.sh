#!/bin/bash

# Function to validate directory
validate_directory() {
    local dir=$1
    while true; do
        if [ -d "$dir" ]; then
            echo "$dir"
            break
        else
            echo "Directory does not exist. Please enter a valid directory path"
            read -p "Enter the full path to your static files directory: " dir
        fi
    done
}

# Update system and install Nginx
echo "Updating system and installing Nginx..."
sudo apt update && sudo apt upgrade -y
sudo apt install nginx -y

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl status nginx

# Configure firewall
echo "Configuring firewall..."
sudo ufw allow 'Nginx HTTP'
sudo ufw enable
sudo ufw status

# Get site name
read -p "Enter your site domain (e.g., example.com): " domain
echo "Enter Domain like xyz.fulldomain.com"

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

# Initialize Nginx configuration
nginx_config="server {
    listen 80;
    server_name $domain;

    # Logging
    access_log /var/log/nginx/$domain-access.log;
    error_log /var/log/nginx/$domain-error.log;

    # Security Headers
    add_header X-Frame-Options \"SAMEORIGIN\" always;
    add_header X-Content-Type-Options \"nosniff\" always;
    add_header X-XSS-Protection \"1; mode=block\" always;
"

if [ "$website_type" = "1" ]; then
    # Static website configuration
    read -p "Enter the full path to your static files directory: " static_dir
    static_dir=$(validate_directory "$static_dir")

    # Create website directory
    sudo mkdir -p /var/www/$domain
    sudo cp -r "$static_dir"/* /var/www/$domain/
    sudo chown -R www-data:www-data /var/www/$domain
    sudo chmod -R 755 /var/www/$domain

    # Add static serving configuration
    nginx_config+="
    root /var/www/$domain;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
    "
elif [ "$website_type" = "2" ]; then
    # Reverse proxy configuration
    read -p "Enter the port number for reverse proxy (e.g., 8090): " proxy_port

    # Add reverse proxy configuration
    nginx_config+="
    location / {
        proxy_pass http://localhost:$proxy_port/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 60s;
    }
    "
fi

# Complete Nginx configuration
nginx_config+="
    # Restrict access to hidden files
    location ~ /\. {
        deny all;
    }
}"

# Write Nginx configuration
echo "$nginx_config" | sudo tee /Etc/nginx/sites-available/$domain

# Enable site by creating symlink and remove default site
sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t
if [ $? -eq 0 ]; then
    sudo systemctl reload nginx
else
    echo "Configuration test failed. Please check /etc/nginx/sites-available/$domain"
    echo "You can also check error logs with: sudo tail -f /var/log/nginx/error.log"
    exit 1
fi

# SSL configuration
read -p "Do you want to configure SSL? (y/n): " ssl_choice
if [ "$ssl_choice" = "y" ] || [ "$ssl_choice" = "Y" ]; then
    echo "Installing Certbot and configuring SSL..."
    sudo apt install certbot python3-certbot-nginx -y
    sudo ufw allow 'Nginx Full'
    sudo ufw delete allow 'Nginx HTTP'
    sudo certbot --nginx -d $domain
    sudo certbot renew --dry-run
    sudo nginx -t
    if [ $? -eq 0 ]; then
        sudo systemctl reload nginx
    else
        echo "SSL configuration test failed. Please check the configuration."
        echo "You can check error logs with: sudo tail -f /var/log/nginx/error.log"
        exit 1
    fi
fi

echo "Setup complete! You can check Nginx error logs with:"
echo "sudo tail -f /var/log/nginx/error.log"


# -----------------------------------------------------------------------------------------------------

# #!/bin/bash

# set -e

# if [ "$(id -u)" -ne 0 ]; then
#   echo -e "\033[31mPlease run this script as root or with sudo.\033[0m" 
#   exit 1
# fi

# echo -n "Enter Website name you want to configure for(like abc.com, amazon.in, subdomain.yourdomain.in etc):"
# read SITE_NAME

# echo -n "Enter the port number where your application server is running (default is 8080): "
# read PORT_NUMBER


# if [ -z "$PORT_NUMBER" ]; then
#     PORT_NUMBER=8080
#     echo "No port entered. Using default port 8080."
# else
#     echo "Using port $PORT_NUMBER for the application server."
# fi

# echo "If you have multiple server on different port then consider changing the nginx config file"


# echo -e "\033[34mUpdating package list...\033[0m"
# apt update -y


# echo -e "\033[34mInstalling Nginx...\033[0m"
# apt install -y nginx


# echo -e "\033[34mAdjusting firewall to allow Nginx HTTP\033[0m" 
# ufw allow 'Nginx HTTP'


# echo -e "\033[34mEnabling Nginx to start on boot...\033[0m"
# systemctl enable nginx


# echo -e "\033[34mStarting Nginx...\033[0m"
# systemctl start nginx

# echo "*********************************************"

# echo "Checking Nginx status..."
# status=$(systemctl is-active nginx)

# if [ "$status" == "active" ]; then
#     echo -e "\033[32mNginx is active\033[0m"   
# else
#     echo -e "\033[31mNginx is not active\033[0m"  
# fi


# echo "Nginx installation and setup completed."
# echo "You can access the default Nginx page at http://<your_server_ip>"




# CONFIG_FILE="/etc/nginx/sites-available/$SITE_NAME"
# echo "Creating Nginx configuration file at $CONFIG_FILE..."
# cat > "$CONFIG_FILE" <<EOF
# server {
#         listen 80;
#         listen [::]:80;

#         root /var/www/$SITE_NAME/html;
#         index index.html index.htm index.nginx-debian.html;

#         server_name $SITE_NAME;
#         access_log /var/log/nginx/access.log;
#         error_log  /var/log/nginx/error.log;

#         location / {
#             proxy_pass http://localhost:$PORT_NUMBER;
#             proxy_read_timeout 240s;
#         }
# }
# EOF
# echo "Nginx config file creation done"
# echo "Enabling the site..."
# ln -s "$CONFIG_FILE" "/etc/nginx/sites-enabled/"

# echo "Testing Nginx configuration..."
# nginx -t

# echo "Reloading Nginx to apply changes..."
# systemctl reload nginx

# echo "*********************************************"

# echo "Nginx is installed and configured."
# echo "Your site is available at http://$SITE_NAME"
# echo "Make sure to update your DNS or add an entry in /etc/hosts for $SITE_NAME."
# echo "If you still want to modify nginx config file then change file which is present in this location: $CONFIG_FILE "

# echo "*********************************************"
# echo "Note: If you want to do ssl in this server then please consider updating your DNS with the Server IP first and then press yes or no."
# echo -n "Do you want to set up SSL for your server? (y/n):"
# read user_input


# if [ "$user_input" == "y" ]; then
#     echo "Now Doing SSL of the server"
#     apt install certbot python3-certbot-nginx -y
#     certbot --nginx -d $SITE_NAME
#     ufw allow 'Nginx Full'
#     ufw delete allow 'Nginx HTTP'
#     echo "*********************************************"
#     echo -e "\033[32mNginx and SSL Setup Complete, Enjoy!!!!!\033[0m"
#     echo "*********************************************"
# else
#     echo "Skipping SSL setup."
#     echo "*********************************************"
#     echo -e "\033[32mNginx Setup Complete, Enjoy!!!!!\033[0m"
#     echo "*********************************************"
# fi

# exit 0

# ---

