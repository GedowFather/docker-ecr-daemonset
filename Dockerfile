FROM alpine:latest

WORKDIR /srv

ADD spot-monitor.sh .
ADD entrypoint.sh .

RUN chmod +x *.sh && \
    apk --update add --no-cache bash curl python3 groff && \
    pip3 install --upgrade --no-cache-dir pip awscli && \
    rm -rf /var/cache/apk/* /tmp/*

ENTRYPOINT /srv/entrypoint.sh

