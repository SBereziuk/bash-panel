[{{DOMAIN}}]
user = {{USER}}
group = {{USER}}
listen = {{PHP_SOCK}}
listen.owner = {{USER}}
listen.group = nginx
listen.mode = 0660
pm = ondemand
pm.max_children = 5
pm.process_idle_timeout = 20s
pm.max_requests = 500
chdir = /
