#!/usr/bin/env bash

set -e

[ -z "$SUDO" ] && SUDO='sudo'

# {{{ Utils

# Return the value of the first argument or exit with an error message if empty.
script-argument-create() {
  [ -z "$1" ] && {
    echo "E: You must specify $2 to '${BASH_SOURCE[0]}'." 1>&2
    exit 1
  }
  echo "$1"
}

# Log an operation
log-operation() {
  local function_name
  local function_values
  local arg
  function_name="$1"
  shift
  for arg in "$@"; do
    function_values="$function_values ""'$( echo "$arg" | sed -e 's#\s\+# #g' )'"
  done
  [ -z "$QUIET" ] && echo "$function_name(""$( echo "$function_values" | sed -e 's#^ ##' -e "s#\s\+''\$##g" )"')...'
}

# }}}

# {{{ Nameservers

# Drop all local 10.0.x.x nameservers in 'resolv.conf'.
nameservers-local-purge() {
  log-operation "$FUNCNAME" "$@"
  $SUDO sed -e 's#nameserver\s*10\.0\..*$##g' -i '/etc/resolv.conf'
}

# Set up an IP as a DNS name server if not already present in 'resolv.conf'.
nameservers-append() {
  log-operation "$FUNCNAME" "$@"
  grep "$1" '/etc/resolv.conf' > /dev/null || \
    ( echo "nameserver $1" | $SUDO tee -a '/etc/resolv.conf' > /dev/null )
}

# }}}

# {{{ Aptitude

# Set up a specific two-letter country code as the preferred `aptitude` mirror.
apt-mirror-pick() {
  log-operation "$FUNCNAME" "$@"
  $SUDO sed -i \
    -e "s#\w\+\.archive\.ubuntu\.com#$1.archive.ubuntu.com#g" \
    -e "s#security\.ubuntu\.com#$1.archive.ubuntu.com#g" \
    '/etc/apt/sources.list'
}

# Add a custom repository as a software source.
apt-packages-repository() {
  log-operation "$FUNCNAME" "$@"
  local apt_repository
  local apt_file
  while [[ "$1" =~ ^deb ]]; do
    apt_repository="$( echo -e "$apt_repository\n$1" )"
    shift
  done
  apt_file=$( echo "$apt_repository" | tail -n1 | sed -e 's#^deb\(-src\)\?\s\+\(\w\+://\)\?##' | system-escape )
  echo "$apt_repository" | $SUDO tee "/etc/apt/sources.list.d/$apt_file.list" >/dev/null
  $SUDO apt-key adv -q --keyserver "${2:-keyserver.ubuntu.com}" --recv-keys "$1" 1>/dev/null
}

# Add a Launchpad PPA as a software source.
apt-packages-ppa() {
  which 'add-apt-repository' >/dev/null || (apt-packages-update; apt-packages-install 'python-software-properties')
  add-apt-repository "$1"
}

# Perform a non-interactive `apt-get` command.
apt-non-interactive() {
  log-operation "$FUNCNAME" "$@"
  $SUDO                                    \
    DEBIAN_FRONTEND=noninteractive         \
    apt-get                                \
      -o Dpkg::Options::='--force-confdef' \
      -o Dpkg::Options::='--force-confold' \
      -f -y -qq                            \
      --no-install-recommends              \
      "$@"
}

# Update `aptitude` packages without any prompts.
apt-packages-update() {
  apt-non-interactive update
}

# Upgrade `aptitude` packages without any prompts.
apt-packages-upgrade() {
  apt-non-interactive upgrade
}

# Perform an unattended installation of package(s).
apt-packages-install() {
  apt-non-interactive install "$@"
}

# Perform an unattended complete removal (purge) of package(s).
apt-packages-purge() {
  local result
  local code
  result=$( apt-non-interactive -q purge "$@" 2>&1 ) || {
    code=$?
    # If no packages matched, it's OK.
    if [[ ! "$result" =~ "E: Couldn't find package" ]]; then
      echo "$result" 1>&2
      exit $code
    fi
  }
  # Take care of any leftovers.
  apt-non-interactive autoremove
}

# }}}

# {{{ System

# Run a complete system (distribution) upgrade.
system-upgrade() {
  apt-non-interactive dist-upgrade
}

# Command a system service, e.g., apache2, mysql, etc.
system-service() {
  log-operation "$FUNCNAME" "$@"
  $SUDO service "$1" "$2" 1>/dev/null
}

# Escape and normalize a string so it can be used safely in file names, etc.
system-escape() {
  while read arg; do
    echo "${arg,,}" | sed -e 's#[^[:alnum:]]\+#-#g' -e 's#^-\+\|-\+$##g'
  done
}

# }}}

# {{{ Default Commands

# Update the Ruby binary link to point to a specific version.
alternatives-ruby-install() {
  log-operation "$FUNCNAME" "$@"
  local bin_path
  local man_path
  bin_path="${2:-/usr/bin/}"
  man_path="${3:-/usr/share/man/man1/}"
  $SUDO update-alternatives                                                         \
    --install "${bin_path}ruby"      ruby      "${bin_path}ruby$1"      "${4:-500}" \
    --slave   "${man_path}ruby.1.gz" ruby.1.gz "${man_path}ruby$1.1.gz"             \
    --slave   "${bin_path}ri"        ri        "${bin_path}ri$1"                    \
    --slave   "${bin_path}irb"       irb       "${bin_path}irb$1"                   \
    --slave   "${bin_path}rdoc"      rdoc      "${bin_path}rdoc$1"
  $SUDO update-alternatives --verbose                                               \
    --set                            ruby      "${bin_path}ruby$1"
}

# Create symbolic links to RubyGems binaries.
alternatives-ruby-gems() {
  log-operation "$FUNCNAME" "$@"
  local ruby_binary
  local ruby_version
  local binary_name
  local binary_path
  ruby_binary=$( $SUDO update-alternatives --query 'ruby' | grep 'Value:' | cut -d' ' -f2- )
  ruby_version="${ruby_binary#*ruby}"
  if grep -v '^[0-9.]*$' <<< "$ruby_version"; then
    echo "E: Could not determine version of RubyGems."
  fi
  for binary_name in "$@"; do
    binary_path="/var/lib/gems/$ruby_version/bin/$binary_name"
    $SUDO update-alternatives --install "$( dirname "$ruby_binary" )/$binary_name" "$binary_name" "$binary_path" 500
    $SUDO update-alternatives --verbose --set                                      "$binary_name" "$binary_path"
  done
}

# }}}

# {{{ Apache

# Enable a list of Apache modules. This requires a server restart.
apache-modules-enable() {
  log-operation "$FUNCNAME" "$@"
  $SUDO a2enmod $*
}

# Disable a list of Apache modules. This requires a server restart.
apache-modules-disable() {
  log-operation "$FUNCNAME" "$@"
  $SUDO a2dismod $*
}

# Enable a list of Apache sites. This requires a server restart.
apache-sites-enable() {
  log-operation "$FUNCNAME" "$@"
  $SUDO a2ensite $*
}

# Disable a list of Apache sites. This requires a server restart.
apache-sites-disable() {
  log-operation "$FUNCNAME" "$@"
  $SUDO a2dissite $*
}

# Create a new Apache site and set up Fast-CGI components.
apache-sites-create() {
  log-operation "$FUNCNAME" "$@"
  local apache_site_name
  local apache_site_path
  local apache_site_user
  local apache_site_group
  local apache_site_config
  local code_block
  apache_site_name="$1"
  apache_site_path="${2:-/$apache_site_name}"
  apache_site_user="${3:-$apache_site_name}"
  apache_site_group="${4:-$apache_site_user}"
  apache_site_config="/etc/apache2/sites-available/$apache_site_name"
  # Define a new virtual host
  code_block=$( cat <<-EOD
<VirtualHost *:80>
  DocumentRoot ${apache_site_path}

  LogLevel debug
  ErrorLog /var/log/apache2/error.${apache_site_name}.log
  CustomLog /var/log/apache2/access.${apache_site_name}.log combined

  # Do not use kernel sendfile to deliver files to the client.
  EnableSendfile Off

  <Directory ${apache_site_path}>
    Options All
    AllowOverride All
  </Directory>
EOD
  )
  # Is PHP required?
  if [ ! -z "$PHP" ]; then
    cgi_action="php-fcgi"
    code_block=$( cat <<-EOD
${code_block}
  <IfModule mod_fastcgi.c>
    <FilesMatch \.php$>
      SetHandler php5-fcgi
    </FilesMatch>
    <Location "/fastcgiphp">
      Order Deny,Allow
      Deny from All
      # Prevent accessing this path directly
      Allow from env=REDIRECT_STATUS
    </Location>
    Action php5-fcgi /fastcgiphp
    Alias /fastcgiphp /usr/local/bin/${apache_site_name}.fpm_external
    FastCgiExternalServer /usr/local/bin/${apache_site_name}.fpm_external -socket /var/run/php5-fpm-${apache_site_name}.sock -pass-header Authorization
  </IfModule>
EOD
    )
    # Run PHP-FPM as the selected user and group.
    $SUDO sed \
      -e 's#^\(\[[A-Za-z0-9-]\+\]\)$#['"$apache_site_name"']#g'   \
      -e 's#^\(user\)\s*=\s*[A-Za-z0-9-]\+#\1 = '"$apache_site_user"'#g'   \
      -e 's#^\(group\)\s*=\s*[A-Za-z0-9-]\+#\1 = '"$apache_site_group"'#g' \
      -e 's#^\(listen\)\s*=\s*.\+$#\1 = '/var/run/php5-fpm-"$apache_site_name"'.sock#g' \
      <'/etc/php5/fpm/pool.d/www.conf' >'/etc/php5/fpm/pool.d/'"$apache_site_name"'.conf'
  fi
  code_block=$( cat <<-EOD
${code_block}
${EXTRA}
</VirtualHost>
EOD
  )
  # Write site configuration to Apache.
  echo "$code_block" | $SUDO tee "$apache_site_config" > /dev/null
}

# Restart the Apache server and reload with new configuration.
apache-restart() {
  system-service apache2 restart
}

# }}}

# {{{ Nginx

# Figure out the path to a particular Nginx site.
nginx-sites-path() {
  echo "/etc/nginx/sites-${2:-available}/$1"
}

# Enable a list of Nginx sites. This requires a server restart.
nginx-sites-enable() {
  log-operation "$FUNCNAME" "$@"
  local name
  local file
  for name in "$@"; do
    file="$( nginx-sites-path "$name" 'enabled' )"
    if [ ! -L "$file" ]; then
      # '-f'orce because '! -L' above would still evaluate for broken symlinks.
      $SUDO ln -fs "$( nginx-sites-path "$name" 'available' )" "$file"
    fi
  done
}

# Disable a list of Nginx sites. This requires a server restart.
nginx-sites-disable() {
  log-operation "$FUNCNAME" "$@"
  local name
  local file
  for name in "$@"; do
    file="$( nginx-sites-path "$name" 'enabled' )"
    if [ -L "$file" ]; then
      $SUDO unlink "$file"
    fi
  done
}

# Create a new Nginx site and set up Fast-CGI components.
nginx-sites-create() {
  log-operation "$FUNCNAME" "$@"
  local nginx_site_name
  local nginx_site_path
  local nginx_site_index
  local nginx_site_user
  local nginx_site_group
  local nginx_site_config
  local code_block
  nginx_site_name="$1"
  nginx_site_path="${2:-/$nginx_site_name}"
  nginx_site_user="${3:-$nginx_site_name}"
  nginx_site_group="${4:-$nginx_site_user}"
  nginx_site_index="${5:-index.html}"
  nginx_site_config="$( nginx-sites-path "$nginx_site_name" 'available' )"
  # Is PHP required?
  if [ ! -z "$PHP" ]; then
    if ! which php5-fpm >/dev/null; then
      echo 'E: You must install php5-fpm to use PHP in Nginx.' 1>&2
      exit 1
    fi
    nginx_site_index="index.php $nginx_site_index"
  fi
  code_block=$( cat <<-EOD
server {
  listen 80;

  root ${nginx_site_path};

  error_log /var/log/nginx/error.${nginx_site_name}.log debug;
  access_log /var/log/nginx/access.${nginx_site_name}.log combined;

  index ${nginx_site_index};

  # Do not use kernel sendfile to deliver files to the client.
  sendfile off;

  # Prevent access to hidden files.
  location ~ /\. {
    access_log off;
    log_not_found off;
    deny all;
  }
EOD
  )
  # Is PHP required?
  if [ ! -z "$PHP" ]; then
    code_block=$( cat <<-EOD
${code_block}

  # Pass PHP scripts to PHP-FPM.
  location ~ \.php\$ {
    include         fastcgi_params;
    fastcgi_index   index.php;
    fastcgi_split_path_info ^(.+\.php)(/.+)\$;
    fastcgi_param   PATH_INFO \$fastcgi_path_info;
    fastcgi_param   PATH_TRANSLATED \$document_root\$fastcgi_path_info;
    fastcgi_param   HTTP_AUTHORIZATION  \$http_authorization;
    fastcgi_pass    unix:/var/run/php5-fpm-${nginx_site_name}.sock;
  }
EOD
    )
    # Run PHP-FPM as the selected user and group.
    $SUDO sed \
      -e 's#^\(\[[A-Za-z0-9-]\+\]\)$#['"$nginx_site_name"']#g'   \
      -e 's#^\(user\)\s*=\s*[A-Za-z0-9-]\+#\1 = '"$nginx_site_user"'#g'   \
      -e 's#^\(group\)\s*=\s*[A-Za-z0-9-]\+#\1 = '"$nginx_site_group"'#g' \
      -e 's#^\(listen\)\s*=\s*.\+$#\1 = '/var/run/php5-fpm-"$nginx_site_name"'.sock#g' \
      <'/etc/php5/fpm/pool.d/www.conf' >'/etc/php5/fpm/pool.d/'"$nginx_site_name"'.conf'
  fi
  code_block=$( cat <<-EOD
${code_block}
${EXTRA}
}
EOD
  )
  # Write site configuration to Nginx.
  echo "$code_block" | $SUDO tee "$nginx_site_config" > /dev/null
}

# Restart the Nginx server and reload with new configuration.
nginx-restart() {
  system-service nginx restart
}

# }}}

# {{{ PHP

# Update a PHP setting value in all instances of 'php.ini'.
php-settings-update() {
  log-operation "$FUNCNAME" "$@"
  local args
  local settings_name
  local php_ini
  local php_extra
  args=( "$@" )
  PREVIOUS_IFS="$IFS"
  IFS='='
  args="${args[*]}"
  IFS="$PREVIOUS_IFS"
  settings_name="$( echo "$args" | system-escape )"
  for php_ini in $( $SUDO find /etc -type f -iname 'php*.ini' ); do
    php_extra="$( dirname "$php_ini" )/conf.d"
    $SUDO mkdir -p "$php_extra"
    echo "$args" | $SUDO tee "$php_extra/0-$settings_name.ini" >/dev/null
  done
}

# Install (download, build, install) and enable a PECL extension.
php-pecl-install() {
  log-operation "$FUNCNAME" "$@"
  local extension
  for extension in "$@"; do
    if ! $SUDO pecl list | grep "^$extension" >/dev/null; then
      $SUDO pecl install -s "$extension" 1>/dev/null
    fi
    php-settings-update 'extension' "$extension.so"
  done
}

# Restart the php5-fpm server and reload with new configuration.
php5-fpm-restart() {
  system-service php5-fpm restart
}

# }}}

# {{{ MySQL

# Create a database if one doesn't already exist.
mysql-database-create() {
  log-operation "$FUNCNAME" "$@"
  mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$1\` CHARACTER SET ${2:-utf8} COLLATE '${3:-utf8_general_ci}'"
}

# Grant access to database (creates user if not exist)
# mysql-database-add-user databasename username password fromhost
mysql-database-add-user() {
  log-operation "$FUNCNAME" "$@"
  mysql -u root -e "GRANT ALL PRIVILEGES ON \`$1\`.* TO '$2'@'${4:-localhost}' IDENTIFIED BY '$3' WITH GRANT OPTION; FLUSH PRIVILEGES;"
}

# Load data from SQL file
# mysql-load-data databasename sqlfile
mysql-load-data() {
  log-operation "$FUNCNAME" "$@"
  mysql -u root "$1" < "$2"
}

# Restore a MySQL database from an archived backup.
mysql-database-restore() {
  log-operation "$FUNCNAME" "$@"
  local backups_database
  local backups_path
  local backups_file
  local tables_length
  backups_database="$1"
  backups_path="$2"
  if [ -d "$backups_path" ]; then
    tables_length=$( mysql -u root --skip-column-names -e "USE '$backups_database'; SHOW TABLES" | wc -l )
    if [ "$tables_length" -lt 1 ]; then
      backups_file=$( find "$backups_path" -maxdepth 1 -type f -regextype posix-basic -regex '^.*[0-9]\{8\}-[0-9]\{4\}.tar.bz2$' | \
        sort -g | \
        tail -1 )
      if [ ! -z "$backups_file" ]; then
        tar -xjf "$backups_file" -O | mysql -u root "$backups_database"
      fi
    fi
  fi
}

# Allow remote passwordless 'root' access for anywhere.
# This is only a good idea if the box is configured in 'Host-Only' network mode.
mysql-remote-access-allow() {
  log-operation "$FUNCNAME" "$@"
  mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '' WITH GRANT OPTION; FLUSH PRIVILEGES;"
  $SUDO sed -e 's#127.0.0.1#0.0.0.0#g' -i '/etc/mysql/my.cnf'
}

# Restart the MySQL server and reload with new configuration.
mysql-restart() {
  system-service mysql restart
}

# }}}

# {{{ RubyGems

# Perform an unattended installation of package(s).
ruby-gems-install() {
  log-operation "$FUNCNAME" "$@"
  $SUDO gem install --no-ri --no-rdoc $*
}

# }}}

# {{{ NPM (Node Package Manager)

# Perform an unattended **global** installation of package(s).
npm-packages-install() {
  log-operation "$FUNCNAME" "$@"
  $SUDO npm config set yes true
  $SUDO npm install -g $*
}

# }}}

# {{{ GitHub

# Download and install RubyGems from GitHub.
github-gems-install() {
  log-operation "$FUNCNAME" "$@"
  local repository
  local clone_path
  local configuration
  which 'git' >/dev/null || apt-packages-install 'git-core'
  which 'gem' >/dev/null || {
    echo 'E: Please install RubyGems to continue.' 1>&2
    exit 1
  }
  for repository in "$@"; do
    configuration=(${repository//@/"${IFS}"})
    clone_path="$( mktemp -d -t 'github-'$( echo "${configuration[0]}" | system-escape )'-XXXXXXXX' )"
    git clone "git://github.com/${configuration[0]}" "$clone_path"
    (                                                   \
      cd "$clone_path"                               && \
      git checkout "${configuration[1]:-master}"     && \
      gem build *.gemspec                            && \
      ruby-gems-install *.gem                           \
    )
    rm -Rf "$clone_path"
  done
}

# }}}
