#!/bin/bash

# Update and install Apache (adjust the package manager for your system)
sudo apt update -y
sudo apt install apache2 -y

# Start and enable Apache
sudo systemctl start apache2
sudo systemctl enable apache2

# Create and edit the index.html file with custom HTML content
echo '<html><head><title>Hello World</title></head>' | sudo tee /var/www/html/index.html
echo '<body>' | sudo tee -a /var/www/html/index.html
echo '<h1>Hello World!</h1>' | sudo tee -a /var/www/html/index.html
echo '</body></html>' | sudo tee -a /var/www/html/index.html

# Install OpenSSL for generating a self-signed certificate (adjust the package manager for your system)
sudo apt install -y openssl

# Generate a self-signed SSL certificate and configure Apache for HTTPS
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/server.key -out /etc/ssl/certs/server.crt -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=example.com"

# Configure Apache for HTTPS
sudo tee /etc/apache2/sites-available/default-ssl.conf <<EOFSSL
<VirtualHost *:443>
ServerAdmin ec2-user@example.com
DocumentRoot /var/www/html

SSLEngine on
SSLCertificateFile /etc/ssl/certs/server.crt
SSLCertificateKeyFile /etc/ssl/private/server.key

ErrorLog \${APACHE_LOG_DIR}/error.log
CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOFSSL

# Enable SSL and restart Apache
sudo a2enmod ssl
sudo a2ensite default-ssl
sudo systemctl restart apache2