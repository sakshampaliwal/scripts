#!/bin/bash

set -e

if [ "$(id -u)" -ne 0 ]; then
  echo -e "\033[31mPlease run this script as root or with sudo.\033[0m" 
  exit 1
fi

echo -n "Enter Website name you want to configure for(like abc.com, amazon.in, subdomain.yourdomain.in etc):"
read SITE_NAME

echo -n "Enter the port number where your application server is running (default is 8080): "
read PORT_NUMBER


if [ -z "$PORT_NUMBER" ]; then
    PORT_NUMBER=8080
    echo "No port entered. Using default port 8080."
else
    echo "Using port $PORT_NUMBER for the application server."
fi

echo "If you have multiple server on different port then consider changing the nginx config file"


echo -e "\033[34mUpdating package list...\033[0m"
apt update -y


echo -e "\033[34mInstalling Nginx...\033[0m"
apt install -y nginx


echo -e "\033[34mAdjusting firewall to allow Nginx HTTP\033[0m" 
ufw allow 'Nginx HTTP'


echo -e "\033[34mEnabling Nginx to start on boot...\033[0m"
systemctl enable nginx


echo -e "\033[34mStarting Nginx...\033[0m"
systemctl start nginx

echo "*********************************************"

echo "Checking Nginx status..."
status=$(systemctl is-active nginx)

if [ "$status" == "active" ]; then
    echo -e "\033[32mNginx is active\033[0m"   
else
    echo -e "\033[31mNginx is not active\033[0m"  
fi


echo "Nginx installation and setup completed."
echo "You can access the default Nginx page at http://<your_server_ip>"




CONFIG_FILE="/etc/nginx/sites-available/$SITE_NAME"
echo "Creating Nginx configuration file at $CONFIG_FILE..."
cat > "$CONFIG_FILE" <<EOF
server {
        listen 80;
        listen [::]:80;

        root /var/www/$SITE_NAME/html;
        index index.html index.htm index.nginx-debian.html;

        server_name $SITE_NAME;
        access_log /var/log/nginx/access.log;
        error_log  /var/log/nginx/error.log;

        location / {
            proxy_pass http://localhost:$PORT_NUMBER;
            proxy_read_timeout 240s;
        }
}
EOF
echo "Nginx config file creation done"
echo "Enabling the site..."
ln -s "$CONFIG_FILE" "/etc/nginx/sites-enabled/"

echo "Testing Nginx configuration..."
nginx -t

echo "Reloading Nginx to apply changes..."
systemctl reload nginx

echo "*********************************************"

echo "Nginx is installed and configured."
echo "Your site is available at http://$SITE_NAME"
echo "Make sure to update your DNS or add an entry in /etc/hosts for $SITE_NAME."
echo "If you still want to modify nginx config file then change file which is present in this location: $CONFIG_FILE "

echo "*********************************************"
echo "Note: If you want to do ssl in this server then please consider updating your DNS with the Server IP first and then press yes or no."
echo -n "Do you want to set up SSL for your server? (y/n):"
read user_input


if [ "$user_input" == "y" ]; then
    echo "Now Doing SSL of the server"
    apt install certbot python3-certbot-nginx -y
    certbot --nginx -d $SITE_NAME
    ufw allow 'Nginx Full'
    ufw delete allow 'Nginx HTTP'
    echo "*********************************************"
    echo -e "\033[32mNginx and SSL Setup Complete, Enjoy!!!!!\033[0m"
    echo "*********************************************"
else
    echo "Skipping SSL setup"
    echo "*********************************************"
    echo -e "\033[32mNginx Setup Complete, Enjoy!!!!!\033[0m"
    echo "*********************************************"
fi

exit 0
