wport = 80
mport = 3306
pport = 8080

mysqluser = "wordpress"
mysqlpass = "wordpress_pass"
mysqlrootpass = "mysqlr00tpwd"
mysqldatabase = "wordpress_db"

puts "On which port should the Wordpress installation be accessible? (default: #{wport})"
input = gets.chomp
wport = input.to_i if input.to_i != 0

puts "On which port should the MySql installation be accessible? (default: #{mport})"
input = gets.chomp
mport = input.to_i if input.to_i != 0

puts "On which port should the phpMyAdmin installation be accessible (default: #{pport})"
input = gets.chomp
pport = input.to_i if input.to_i != 0

puts "Please set a the MySql username (def: #{mysqluser})"
input = gets.chomp
mysqluser = input if input.to_s.length > 1

puts "Please set a the MySql pass (def: #{mysqlpass})"
input = gets.chomp
mysqlpass = input if input.to_s.length > 1

puts "Please set a the MySql root-pass (def: #{mysqlrootpass})"
input = gets.chomp
mysqlrootpass = input if input.to_s.length > 1

puts "Please set a the MySql database name (def: #{mysqldatabase})"
input = gets.chomp
mysqldatabase = input if input.to_s.length > 1



puts "CREATING FOLDER STRUCTURE AND DOWNLOADING LATEST WORDPRESS..."
sleep 1
value = `
mkdir html
cd html
curl -O https://wordpress.org/latest.tar.gz
tar -zxvf latest.tar.gz --strip 1
rm latest.tar.gz
cd ../
mkdir mysql
cd mysql
mkdir data
cd ../
mkdir nginx
cd nginx
mkdir errors
cd ../
mkdir php
`
puts "CREATED FOLDER STRUCTURE AND DOWNLOADED WORDPRESS!"
sleep 1

def createFile(path,contents)
  out_file = File.new(path, "w")
  out_file.puts(contents)
  out_file.close
end

puts "CREATING docker-compose.yml"
content = "
nginx:
    container_name: nginxBaseServer
    build: ./nginx/
    ports:
        - #{wport}:80
    links:
        - php
    volumes:
        - ./html:/var/www/html
        - ./nginx/errors:/var/log/nginx

php:
    build: ./php/
    expose:
        - 9000
    volumes:
        - ./html:/var/www/html
    links:
        - mysql

mysql:
    image: mysql:latest
    expose:
      - 3306
    ports:
      - #{mport}:3306
    environment:
        MYSQL_ROOT_PASSWORD: #{mysqlrootpass}
        MYSQL_DATABASE: #{mysqldatabase}
        MYSQL_USER: #{mysqluser}
        MYSQL_PASSWORD: #{mysqlpass}
    volumes:
      - ./mysql/data:/var/lib/mysql

phpmyadmin:
    image: phpmyadmin/phpmyadmin
    ports:
        - #{pport}:80
    links:
        - mysql
    environment:
        PMA_HOST: mysql
"
createFile("docker-compose.yml",content)

puts "CREATING NGINX DOCKERFILE AND CONFIG"

content = "
FROM nginx:latest

COPY default.conf /etc/nginx/conf.d/default.conf
"

createFile("./nginx/Dockerfile",content)

content = "
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log error;

    sendfile off;

    client_max_body_size 100m;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    location ~ /\.ht {
        deny all;
    }
}

"
createFile("./nginx/default.conf",content)

puts "CREATING PHP.INI AND DOCKERFILE"

content = "
FROM php:7.0-fpm

RUN docker-php-ext-install pdo_mysql
RUN docker-php-ext-install mysqli

COPY php.ini /usr/local/etc/php
"

createFile("./php/Dockerfile",content)


content = "
display_errors = On
log_errors = On
error_log = /var/log/php-errors.log
"
createFile("./php/php.ini",content)

puts "ALL SET, STARTING DOCKER."

value = `
docker-compose up -d
`

puts "\n\n\n"
puts "------------------------------------------"
puts "DONE (:. WordPress docker is now running."
puts "Connection details:"
puts "WordPress is accessible under: http://localhost:#{wport}"
puts "phpMyAdmin is accessible under: http://localhost:#{pport}"
puts "MySQL is accessible under:"
puts "  Port: #{mport}"
puts "  WordPress database: #{mysqldatabase}"
puts "  Username: #{mysqluser}"
puts "  Password: #{mysqlpass}"
puts "  (MySQL root pass: #{mysqlrootpass})"
puts
puts "Start your WordPress configuration:"
puts "  1. URL: http://localhost:#{wport}/wp-admin/install.php"
puts "  2. Enter mySQL data."
puts "  3. PLEASE NOTE: The MySQL host is: 'mysql' !"


#Remove all Docker images: docker rmi $(docker images -q)
#Remove all Docker containers: docker rm $(docker ps -a -q)
