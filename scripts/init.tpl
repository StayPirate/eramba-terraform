#cloud-config

repo_update: all
repo_upgrade: all

packages:
  - docker
  - git
  - curl
  - mysql
  - awscli

system_info:
  default_user:
    name: ${USER}
    gecos: "Operations User"
    primary-group: ${USER}
    shell: /bin/bash
    lock_passwd: true
    sudo: ['ALL=(ALL) NOPASSWD:ALL']

output:
  all: '| tee -a /var/log/cloud-init-output.log'