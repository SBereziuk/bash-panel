server {
    listen {{SERVER_IP}}:80;
    server_name {{DOMAIN}} www.{{DOMAIN}};
    root /home/{{USER}}/domains/{{DOMAIN}};
    index index.php index.html;

    access_log /home/{{USER}}/logs/{{DOMAIN}}_access.log;
    error_log /home/{{USER}}/logs/{{DOMAIN}}_error.log;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_intercept_errors on;
        fastcgi_pass unix:{{PHP_SOCK}};
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
