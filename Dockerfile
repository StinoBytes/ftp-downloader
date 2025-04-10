FROM alpine:3.15

# Install required packages
RUN apk add --no-cache \
    lftp \
    sqlite \
    bash \
    tzdata \
    coreutils \
    busybox-suid

# Create directories with explicit permissions
RUN mkdir -p /app /data /db /var/log && \
    chmod 777 /data /db

# Copy scripts into the container
COPY scripts/* /app/

# Set permissions for scripts
RUN chmod +x /app/*.sh

# Environment variables
ENV FTP_HOST="" \
    FTP_USER="" \
    FTP_PASS="" \
    FTP_SOURCE="/" \
    FTP_TARGET="/data" \
    DOWNLOAD_HOURS="0-23" \
    TZ="UTC"

WORKDIR /app

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["crond", "-f", "-d", "8"]
