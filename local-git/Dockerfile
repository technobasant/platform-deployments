# An in-cluster Git server so Argo CD has a remote to watch before the repository is
# public, and so measurements can push throwaway commits without touching history.
FROM python:3.12-alpine
RUN apk add --no-cache git \
 && pip install --no-cache-dir dulwich==0.24.10 \
 && adduser -D -u 10001 git
COPY serve.sh /usr/local/bin/serve.sh
USER 10001
EXPOSE 8080
ENTRYPOINT ["/bin/sh", "/usr/local/bin/serve.sh"]
