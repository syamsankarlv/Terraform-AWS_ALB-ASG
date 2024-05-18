#!/bin/bash

# Update SSH configuration
echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
sed -i '/^LANG=/d' /etc/environment
echo "LANG=en_US.utf-8" >> /etc/environment
sed -i '/^LC_ALL=/d' /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment

# Set root password
echo "password123" | passwd root --stdin

# Enable root login and password authentication in SSH
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
service sshd restart

# Install necessary packages
yum install httpd php git -y

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Clone website repository and deploy
git clone https://github.com/syamsankarlv/aws-elb-site /var/website
cp -r /var/website/* /var/www/html/
chown -R apache:apache /var/www/html/*