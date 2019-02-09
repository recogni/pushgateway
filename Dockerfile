FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install -y \
        curl \
        gcc \
        git \
        make && \
    curl -s -L https://dl.google.com/go/go1.11.5.linux-amd64.tar.gz | \
        tar -xzf - -C /usr/local && \
    rm -rf /var/lib/apt/lists/*

COPY . /workspace

RUN GOROOT=/usr/local/go PATH=${GOROOT}/bin:${PATH} \
        make -C /workspace && \
    cp /workspace/pushgateway / && \
    rm -rf /workspace


FROM quay.io/prometheus/busybox:latest
LABEL maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"

COPY --from=0 pushgateway /bin/pushgateway

EXPOSE 9091
RUN mkdir -p /pushgateway
WORKDIR /pushgateway
ENTRYPOINT [ "/bin/pushgateway" ]
