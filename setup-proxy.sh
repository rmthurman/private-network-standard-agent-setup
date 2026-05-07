#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx libnginx-mod-stream > /dev/null 2>&1

cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
}

stream {
    map $ssl_preread_server_name $backend {
        foundrype4cey.cognitiveservices.azure.com     10.200.3.12:443;
        foundrype4cey.openai.azure.com                10.200.3.13:443;
        foundrype4cey.services.ai.azure.com           10.200.3.14:443;
        foundrypesqxkstorage.blob.core.windows.net    10.200.3.10:443;
        foundrypesqxkcosmosdb.documents.azure.com     10.200.3.4:443;
        default                                       10.200.3.12:443;
    }

    server {
        listen 443;
        ssl_preread on;
        proxy_pass $backend;
        proxy_connect_timeout 5s;
        proxy_timeout 300s;
    }
}
EOF

nginx -t 2>&1
systemctl restart nginx
systemctl enable nginx
echo "nginx status: $(systemctl is-active nginx)"
ss -tlnp | grep 443
