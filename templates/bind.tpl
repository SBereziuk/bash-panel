$TTL 86400
@   IN  SOA ns1.yourpanel.com. admin.{{DOMAIN}}. (
        {{SERIAL}} ; serial
        3600       ; refresh
        1800       ; retry
        604800     ; expire
        86400      ; minimum
)
@       IN  NS      ns1.yourpanel.com.
@       IN  NS      ns2.yourpanel.com.
@       IN  A       {{SERVER_IP}}
www     IN  A       {{SERVER_IP}}
@       IN  MX 10   mail.{{DOMAIN}}.
mail    IN  A       {{SERVER_IP}}
