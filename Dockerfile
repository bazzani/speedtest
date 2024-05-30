FROM debian:stable-20240513-slim

# Install basics
RUN apt-get update && apt-get install -y curl jq gnupg1 apt-transport-https dirmngr \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install speedtest cli
RUN curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
RUN apt-get install -y speedtest \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY ./speedtest.sh .
CMD ["./speedtest.sh"]
