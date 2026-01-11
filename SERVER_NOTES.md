# Server Configuration Notes - [2026-01-11]

This document contains detailed technical records of the changes made to the mail and FTP systems for the Bash Panel.

## 1. Global Mail User (vmail)
To avoid permission conflicts, all virtual mailboxes are managed by a single system user.

- **Command:**
  ```bash
  groupadd -g 5000 vmail
  useradd -u 5000 -g vmail -s /usr/sbin/nologin -d /var/bash_panel/vmail -m vmail
  # Grant Dovecot permission to read mail files through group
  usermod -aG vmail dovecot	

    Auth File: /var/bash_panel/mail_users

        Permissions: 644 (Owner: root)

        Format: user@domain:$1$salt$hash:5000:5000::/path/to/maildir:/sbin/nologin


2. Dovecot Detailed Setup

Dovecot is configured as the MDA (Mail Delivery Agent) and Authentication Provider.
2.1 Main Auth Config

File: /etc/dovecot/conf.d/10-auth.conf

disable_plaintext_auth = yes
auth_mechanisms = plain login
#!include auth-system.conf.ext
!include auth-passwdfile.conf.ext


Password File Driver

File: /etc/dovecot/conf.d/auth-passwdfile.conf.ext

passdb {
  driver = passwd-file
  args = scheme=MD5-CRYPT username_format=%u /var/bash_panel/mail_users
}

userdb {
  driver = passwd-file
  args = username_format=%u /var/bash_panel/mail_users
}

2.3 Master Socket (For Exim)

File: /etc/dovecot/conf.d/10-master.conf

service auth {
  unix_listener auth-client {
    mode = 0660
    user = exim
    group = exim
  }
}

Exim Detailed Setup

Exim acts as the MTA (Mail Transfer Agent).
3.1 Routers (Logic to find mail)

File: /etc/exim/exim.conf (Section: ROUTERS)

virtual_domains:
  driver = accept
  domains = dsearch;/etc/exim/domains
  condition = ${if exists{/var/bash_panel/mail_users}{yes}{no}}
  transport = virtual_localdelivery

3.2 Transports (How to save mail)

File: /etc/exim/exim.conf (Section: TRANSPORTS)

virtual_localdelivery:
  driver = appendfile
  create_directory
  # Extract path from the 6th field of the mail_users file
  directory = ${extract{6}{:}{${lookup{$local_part@$domain}lsearch{/var/bash_panel/mail_users}}}}/Maildir
  maildir_format
  user = vmail
  group = vmail
  mode = 0600

3.3 Authenticators (How users log in)

File: /etc/exim/exim.conf (Section: AUTHENTICATORS)

dovecot_plain:
  driver = dovecot
  public_name = PLAIN
  server_socket = /var/run/dovecot/auth-client
  server_set_id = $auth1

dovecot_login:
  driver = dovecot
  public_name = LOGIN
  server_socket = /var/run/dovecot/auth-client
  server_set_id = $auth1

4. Pure-FTPd Detailed Setup

Configured to use a virtual database instead of system users.

    Configuration:
    Bash

    echo "no" > /etc/pure-ftpd/conf/PAMAuthentication
    echo "no" > /etc/pure-ftpd/conf/UnixAuthentication
    echo "/etc/pure-ftpd/pureftpd.pdb" > /etc/pure-ftpd/conf/PureDB

5. Summary of Panel Commands

    Password Hashing: openssl passwd -1 "password"

    Directory Structure: /home/[user]/mail/[domain]/[account]

    Ownership: Files inside Maildir must be vmail:vmail (5000:5000).
