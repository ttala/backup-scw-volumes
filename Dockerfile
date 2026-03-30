FROM alpine:3.20

RUN apk add --no-cache bash curl jq ca-certificates

ARG SCW_VERSION=2.41.0
RUN curl -fsSL "https://github.com/scaleway/scaleway-cli/releases/download/v${SCW_VERSION}/scaleway-cli_${SCW_VERSION}_linux_amd64" -o /usr/local/bin/scw \
    && chmod +x /usr/local/bin/scw \
    && scw version

WORKDIR /app
COPY backup.sh /app/backup.sh
RUN chmod +x /app/backup.sh

CMD ["/app/backup.sh"]