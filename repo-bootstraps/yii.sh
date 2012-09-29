<%
@vhostExtra='
    location ~ ^/(protected|framework|themes/\w+/views) {
        deny  all;
    }

    #avoid processing of calls to static files by yii
    location ~ \.(js|css|png|jpg|gif|swf|ico|pdf|mov|fla|zip|rar)$ {
        try_files $uri =404;
    }

    location ~ /\.ht {
        deny  all;
    }
'
%>

if ! [ -d /var/www/yii/public ]
then
    cd /var/www/yii
    chmod +x framework/yiic
    yes | ./framework/yiic webapp ./public
    mv ./public/protected .
fi

# Create db
mysql-database-create yiiapp

# Add user (database, username, password)
mysql-database-add-user yiiapp yiiapp yiiapp

# Load db
#mysql-load-data yiiapp "/var/www/yii/protected/data/schema.mysql.sql"

sed -i -e "s#'/protected#'/../protected#g" /var/www/yii/public/index.php
sed -i -e "s#'/protected#'/../protected#g" /var/www/yii/public/index-test.php
sed -i -e "s#'/../../framework#'/../framework#g" /var/www/yii/protected/yiic.php

# Update config
cat >/var/www/yii/protected/config/main.php <<EOF
<?php

return array(
   'basePath'=>dirname(__FILE__).DIRECTORY_SEPARATOR.'..',
   'name'=>'My Vagrant YiiApp',
   'preload'=>array('log'),
   'import'=>array(
       'application.models.*',
       'application.components.*',
   ),
   'modules'=>array(
       'gii'=>array(
           'class'=>'system.gii.GiiModule',
           'password'=>'yiiapp',
           // If removed, Gii defaults to localhost only. Edit carefully to taste.
           'ipFilters'=>array('127.0.0.1','::1','192.168.33.1'),
       ),
   ),
   'components'=>array(
       'user'=>array(
           // enable cookie-based authentication
           'allowAutoLogin'=>true,
       ),
       'urlManager'=>array(
           'urlFormat'=>'path',
           'showScriptName'=>false,
       ),
       'db'=>array(
           'connectionString' => 'mysql:host=localhost;dbname=yiiapp',
           'emulatePrepare' => true,
           'username' => 'yiiapp',
           'password' => 'yiiapp',
           'charset' => 'utf8',
       ),
       'errorHandler'=>array(
           'errorAction'=>'site/error',
       ),
       'log'=>array(
           'class'=>'CLogRouter',
           'routes'=>array(
               array(
                   'class'=>'CFileLogRoute',
                   'levels'=>'error, warning',
               ),
               array(
                   'class'=>'CWebLogRoute',
                   'levels'=>'error,warning,info',
               ),
           ),
       ),
   ),
   'params'=>array(
       // this is used in contact page
       'adminEmail'=>'webmaster@yii.vagrant',
   ),
);
EOF
