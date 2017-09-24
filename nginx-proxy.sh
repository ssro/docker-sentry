#!/bin/bash

# Nginx reverse proxy for sentry deployment
# Full SSL suport with Lets Encrypt

# In order to have SSL support, please have a DNS A record for your sentry host
# otherwise the host won't be accessible and the certificate generation will fail

# Get the nginx template
sudo bash -c "curl https://raw.githubusercontent.com/jwilder/nginx-proxy/master/nginx.tmpl > $(etcdctl get /nginx/WORKDIR)/nginx.tmpl || exit 0"

# Start containers
docker run -d -p 80:80 -p 443:443 \
    --network=sentry_net \
    --restart=always \
    --name nginx \
    -v /etc/nginx/conf.d  \
    -v /etc/nginx/vhost.d \
    -v /usr/share/nginx/html \
    -v $(etcdctl get /nginx/WORKDIR)/certs:/etc/nginx/certs:ro \
    --label com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy \
    nginx
docker network connect bridge nginx
docker run -d \
    --network=sentry_net \
    --restart=always \
    --name nginx-gen \
    --volumes-from nginx \
    -v $(etcdctl get /nginx/WORKDIR)/nginx.tmpl:/etc/docker-gen/templates/nginx.tmpl:ro \
    -v /var/run/docker.sock:/tmp/docker.sock:ro \
    --label com.github.jrcs.letsencrypt_nginx_proxy_companion.docker_gen \
    jwilder/docker-gen \
    -notify-sighup nginx -watch -wait 5s:30s /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf


docker run -d \
    --network=sentry_net \
    --restart=always \
    --name nginx-letsencrypt \
    --volumes-from nginx \
    -v $(etcdctl get /nginx/WORKDIR)/certs:/etc/nginx/certs:rw \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    jrcs/letsencrypt-nginx-proxy-companion
