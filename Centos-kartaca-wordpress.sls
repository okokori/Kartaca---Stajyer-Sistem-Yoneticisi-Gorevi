# Kartaca kullanıcısını oluşturma ve sudo yetkisi verme
create_kartaca_user:
  user.present:
    - name: kartaca
    - uid: 2024
    - gid: 2024
    - home: /home/krt
    - shell: /bin/bash

  group.present:
    - name: kartaca
    - gid: 2024

  group.members:
    - kartaca

  file.managed:
    - name: /etc/sudoers.d/kartaca
    - source: salt://files/kartaca_sudoers
    - template: jinja

# Sunucu timezone’unu Istanbul olarak ayarla
set_timezone:
  timezone.system:
    - name: Europe/Istanbul

# IP Forwarding'i kalıcı olarak enable et
enable_ip_forwarding:
  sysctl.persist:
    - name: net.ipv4.ip_forward
    - value: 1

# Gerekli paketleri kurma
install_required_packages:
  pkg.installed:
    - names:
      - htop
      - tcptraceroute
      - ping
      - bind-utils
      - sysstat
      - mtr

# Hashicorp reposunu ekleyip Terraform kurma
install_terraform:
  pkgrepo.managed:
    - name: hashicorp
    - humanname: Hashicorp Official Repository
    - file: /etc/yum.repos.d/hashicorp.repo
    - baseurl: https://rpm.releases.hashicorp.com/RHEL/7/$basearch/stable
    - gpgkey: https://rpm.releases.hashicorp.com/gpg
    - clean_file: True

  pkg.installed:
    - name: terraform
    - version: 1.6.4

# /etc/hosts dosyasına IP bloğu için host kayıtlarını ekle
add_hosts_entries:
  file.append:
    - name: /etc/hosts
    - text: |
        {% for i in range(128, 144) %}
        192.168.168.{{ i }} kartaca.local
        {% endfor %}

# Nginx, PHP ve WordPress kurulumu
install_nginx_php_wordpress:
  pkg.installed:
    - names:
      - nginx
      - php-fpm
      - php-mysql
      - php-gd
      - php-xml
      - php-mbstring
      - php-json

# Wordpress arşiv dosyasını /var/www/wordpress2024 dizinine indir
download_wordpress:
  cmd.run:
    - name: wget -P /var/www/wordpress2024 https://wordpress.org/latest.tar.gz

# Wordpress arşiv dosyasını aç
extract_wordpress:
  cmd.run:
    - name: tar -zxvf /var/www/wordpress2024/latest.tar.gz -C /var/www/wordpress2024

# Nginx yapılandırması her güncellendiğinde Nginx servisini reload et
reload_nginx_service:
  service.running:
    - name: nginx
    - reload: True

# Wordpress veritabanı bilgilerini wp-config.php dosyasına ekle
configure_wordpress:
  file.replace:
    - name: /var/www/wordpress2024/wp-config.php
    - pattern: 'database_name_here'
    - repl: {{ pillar['wordpress']['kartaca'] }}
  file.replace:
    - name: /var/www/wordpress2024/wp-config.php
    - pattern: 'username_here'
    - repl: {{ pillar['wordpress']['krt'] }}
  file.replace:
    - name: /var/www/wordpress2024/wp-config.php
    - pattern: 'password_here'
    - repl: {{ pillar['wordpress']['Kartaca2024'] }}

# Wordpress secret ve keyleri wp-config.php dosyasına ekle
configure_wordpress_keys:
  cmd.run:
    - name: curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/wordpress2024/wp-config.php

# Self-signed SSL sertifikası oluştur
generate_ssl_certificate:
  cmd.run:
    - name: openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/C=TR/ST=Istanbul/L=Istanbul/O=Global Security/OU=IT Department/CN=kartaca.local"

# Nginx yapılandırması her güncellendiğinde SSL sertifikasını dahil et
include_ssl_certificate:
  file.replace:
    - name: /etc/nginx/nginx.conf
    - pattern: 'server_name_in_redirect off;'
    - repl: |
        server_name_in_redirect off;
        include /etc/nginx/snippets/self-signed.conf;

# Nginx loglarını saatlik olarak rotate et
rotate_nginx_logs:
  file.append:
    - name: /etc/crontab
    - text: "0 * * * * root /usr/sbin/logrotate /etc/logrotate.conf"