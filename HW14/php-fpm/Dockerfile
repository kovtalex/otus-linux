FROM alpine:3.14

RUN adduser -S www-data -G www-data && apk add --no-cache php7 php7-fpm && rm -rf /var/cache/apk/*

COPY php-fpm.conf /etc/php7/

ENTRYPOINT ["/usr/sbin/php-fpm7"]
CMD ["-F", "--fpm-config", "/etc/php7/php-fpm.conf"]
