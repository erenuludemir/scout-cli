FROM nginx:1.27.2-alpine

LABEL maintainer="qai"

RUN rm -f /var/log/nginx/access.log /var/log/nginx/error.log \
 && touch /var/log/nginx/access.log /var/log/nginx/error.log

# This file is a full nginx config, not a conf.d server snippet.
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O- http://localhost:8080/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
