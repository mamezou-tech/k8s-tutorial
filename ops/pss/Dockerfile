FROM alpine:latest
RUN apk --no-cache update \
    && apk --no-cache add sudo
RUN adduser -D sample --uid 1001 \
    && echo "app ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sample \
    && chmod 0440 /etc/sudoers.d/sample
ENTRYPOINT ["sh", "-c", "whoami && sleep infinity"]
