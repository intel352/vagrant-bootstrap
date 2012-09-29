#!/usr/bin/env bash

# {{{ Ubuntu utilities

<%= render 'vagrant-shell-scripts/ubuntu.sh' %>

# }}}

# Use Google Public DNS for resolving domain names.
# The default is host-only DNS which may not be installed.
nameservers-local-purge
nameservers-append '8.8.8.8'
nameservers-append '8.8.4.4'

# Use a local Ubuntu mirror, results in faster downloads.
apt-mirror-pick 'us'

# Add MongoDB repo
apt-packages-repository 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' '7F0CEB10'
# Add NodeJS repo
apt-packages-ppa ppa:chris-lea/node.js

# Update packages cache.
apt-packages-update

# Upgrade packages
apt-packages-upgrade

# Install VM packages.
apt-packages-install     \
  git-core               \
  mercurial              \
  nodejs                 \
  npm                    \
  imagemagick            \
  curl                   \
  memcached              \
  mongodb-10gen          \
  mysql-server           \
  nginx-full             \
  php5-fpm               \
  php5-cli               \
  php-apc                \
  php5-gd                \
  php5-imagick           \
  php5-curl              \
  php5-memcache          \
  php5-memcached         \
  php5-mcrypt            \
  php5-mysqlnd           \
  ack-grep

# Rename ack-grep to ack, this is preferential only
dpkg-divert --local --divert /usr/bin/ack --rename --add /usr/bin/ack-grep

# Disable default nginx vhost
nginx-sites-disable 'default'
mkdir -p /var/www

# Configure SSH for task automation
mkdir -p ~/.ssh
touch ~/.ssh/known_hosts
# Add git host to known hosts
ssh-keyscan -H <%=@gitUri.match('^(?:(?:(?:git|https?)://)?(?:[\w\d-]+(?::[\w\d-]+)?@)?)?([^@:/]+)')[1]%> >> ~/.ssh/known_hosts

# {{{ Import repo bootstraps

<%
repos = []
bootstraps = Dir.glob('repo-bootstraps/*.sh')
bootstraps.each do |r|
  repo = r[16..-4]
  repos << repo
  @vhostExtra = ''
  %>
[ -d /vagrant/repos/<%=repo%> ] || (cd /vagrant/repos; git clone <%=@gitUri+repo+'.git'%>)
[ -L /var/www/<%=repo%> ] || ln -sf /vagrant/repos/<%=repo%> /var/www/<%=repo%>
  <%= render r %>
PHP=true EXTRA='
  server_name <%=repo%>.vagrant;
  location / {
    try_files $uri $uri/ /index.php?$args;
  }
  <%=@vhostExtra%>
' nginx-sites-create '<%=repo%>' '/var/www/<%=repo%>/public' 'vagrant'
nginx-sites-enable '<%=repo%>'
  <%
end
%>

echo '127.0.0.1 <%=repos.join('.vagrant ')%>' >> /etc/hosts

# }}}

# Allow unsecured remote access to MySQL.
mysql-remote-access-allow

# Restart all services
php5-fpm-restart
nginx-restart
mysql-restart

echo '!!! Provisioning is complete. If vagrant has not yet exited, please press CTRL-C twice. !!!'