#!/bin/bash

echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment

echo "password123" | passwd root --stdin
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
service sshd restart
systemctl restart sshd

yum install httpd php -y
systemctl restart httpd
systemctl enable httpd

cat <<EOF > /var/www/html/index.php
<?php
\$output = shell_exec('echo \$HOSTNAME');
echo "<h1><center><pre>\$output</pre></center></h1>";
echo "<h1><center>Terraform Site</center></h1>";
?>
EOF