FROM debian:stable-slim AS dnsmasq-builder

RUN dpkg --add-architecture amd64 \
 && apt-get update \
 && apt-get -y install git make libc6-dev:amd64 gcc nettle-dev libunistring-dev libnetfilter-conntrack-dev libidn11-dev libidn2-dev libidn2-0-dev libdbus-1-dev gettext \
 && git clone -b master git://thekelleys.org.uk/dnsmasq.git /dnsmasq \
 && cd /dnsmasq/ \
 && CC=gcc make COPTS='-DHAVE_DNSSEC -DHAVE_DNSSEC_STATIC -DHAVE_IDN -DHAVE_IDN_STATIC -DHAVE_LIBIDN2 -DHAVE_LIBIDN2_STATIC -DNO_DHCP -DNO_DHCP6 -DNO_TFTP -DNO_SCRIPT' install \
 && cp /dnsmasq/dnsmasq.conf.example /etc/dnsmasq.conf

FROM busybox:glibc AS user-builder

RUN addgroup -g 200 -S dnsmasq \
 && adduser -G dnsmasq -s /bin/false -S -D -H -u 200 dnsmasq \
 && mkdir -p /etc/dnsmasq.d/ \
 && mkdir -p /var/run/ \
 && mkdir -p /var/lib/misc/ \
 && mkdir -p /var/ftpd/

FROM amd64/busybox:glibc

COPY --from=user-builder /etc/passwd /etc/passwd
COPY --from=user-builder /etc/group /etc/group
COPY --from=user-builder /etc/shadow /etc/shadow

COPY --from=dnsmasq-builder /usr/local/sbin/dnsmasq /usr/sbin/dnsmasq
COPY --from=dnsmasq-builder --chown=dnsmasq:dnsmasq /etc/dnsmasq.conf /etc/dnsmasq.conf

COPY --from=user-builder --chown=dnsmasq:dnsmasq /etc/dnsmasq.d/ /etc/dnsmasq.d/
COPY --from=user-builder /var/run/ /var/run/
COPY --from=user-builder /var/lib/misc/ /var/lib/misc/
COPY --from=user-builder /var/ftpd/ /var/ftpd/

VOLUME     [ "/etc/dnsmasq.d/", \
             "/var/lib/misc/" ]

EXPOSE     53/tcp 53/udp 67/udp

ENTRYPOINT [ "dnsmasq" ]
CMD        [ "--keep-in-foreground", \
             "--user=dnsmasq", \
             "--log-facility=-", \
             "--log-dhcp" ]
