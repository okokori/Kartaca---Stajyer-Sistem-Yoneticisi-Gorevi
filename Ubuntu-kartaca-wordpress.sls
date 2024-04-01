# kartaca-wordpress.sls

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

set_timezone:
  timezone.system:
    - name: Europe/Istanbul

enable_ip_forwarding:
  sysctl.present:
    - name: net.ipv4.ip_forward
    - value: 1
    - apply: True

install_required_packages:
  pkg.installed:
    - names:
      - htop
      - tcptraceroute
      - iputils-ping
      - dnsutils
      - sysstat
      - mtr-tiny

install_terraform:
  pkgrepo.managed:
    - name: hashicorp
    - humanname: Hashicorp Official Repository
    - file: /etc/apt/sources.list.d/hashicorp.list
    - baseurl: https://apt.releases.hashicorp.com
    - gpgkey: https://apt.releases.hashicorp.com/gpg
    - clean_file: True

  pkg.installed:
    - name: terraform
    - version: 1.6.4

add_hosts_entries:
  file.append:
    - name: /etc/hosts
    - text: |
        {% for i in range(1, 16) %}
        192.168.168.{{ 127 + i }}/32 kartaca.local
        {% endfor %}


install_mysql:
  pkg.installed:
    - name: mysql-server

configure_mysql_service:
  service.running:
    - name: mysql
    - enable: True

create_mysql_database_user:
  mysql_user.present:
    - name: {{ pillar['wordpress']['kartaca'] }}
    - host: localhost
    - password: {{ pillar['wordpress']['kartaca2024'] }}
    - connection_user: root
    - connection_pass: {{ pillar['mysql']['kartaca2024'] }}

create_mysql_database:
  mysql_database.present:
    - name: {{ pillar['wordpress']['krt'] }}
    - owner: {{ pillar['wordpress']['kartaca'] }}

create_mysql_backup_cron:
  cron.present:
    - name: backup_mysql
    - user: root
    - minute: 0
    - hour: 2
    - job: "/usr/bin/mysqldump -u root -p{{ pillar['mysql']['kartaca2024'] }} {{ pillar['wordpress']['krt'] }} > /backup/{{ pillar['wordpress']['krt'] }}_$(date +\%Y\%m\%d).sql"