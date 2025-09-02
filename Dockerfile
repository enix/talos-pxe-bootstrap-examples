FROM ubuntu:noble AS builder-ipxe
ARG iPXE_VERSION=7e64e9b6703e6dd363c063d545a5fe63bbc70011
RUN apt-get -y -qq --force-yes update && \
    apt-get -y -qq --force-yes install curl build-essential liblzma-dev genisoimage
RUN curl -L https://github.com/ipxe/ipxe/archive/${iPXE_VERSION}.tar.gz | tar -xz
WORKDIR /ipxe-${iPXE_VERSION}/src
RUN sed -i 's/^#undef[\t ]DOWNLOAD_PROTO_HTTPS.*$/#define DOWNLOAD_PROTO_HTTPS/g' config/general.h

RUN mkdir /built
RUN make bin/ipxe.pxe && cp bin/ipxe.pxe /built
RUN make bin-x86_64-efi/ipxe.efi && cp bin-x86_64-efi/ipxe.efi /built


FROM python:3.13-slim AS config-renderer
COPY ./nodes /nodes
COPY ./merge.py /merge.py
COPY ./templates /templates
COPY --from=gomplate/gomplate:v4.3 /gomplate /bin/gomplate
RUN pip install pyyaml
RUN ./merge.py /nodes/ | gomplate --datasource nodes=stdin://nodes.json --output-dir=/rendered --input-dir=/templates


FROM debian:bookworm AS runtime

RUN apt-get -y -qq --force-yes update && apt-get -y -qq --force-yes install -y dnsmasq

RUN mkdir /tftproot

COPY --from=builder-ipxe /built/ipxe.pxe /tftproot/
COPY --from=builder-ipxe /built/ipxe.efi /tftproot/
COPY --from=config-renderer /rendered/ipxe.conf /tftproot/
COPY --from=config-renderer /rendered/dnsmasq.conf /dnsmasq.conf

EXPOSE 67/udp
EXPOSE 69/udp

CMD ["dnsmasq", "--conf-file=/dnsmasq.conf", "--keep-in-foreground", "--user=root", "--log-facility=-", "--port=0"]
