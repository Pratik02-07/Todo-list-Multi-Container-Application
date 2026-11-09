FROM nginx:1.27-alpine

LABEL org.opencontainers.image.title="Todo List Web UI Frontend" \
      org.opencontainers.image.description="Nginx static web server and reverse proxy for Todo List application" \
      org.opencontainers.image.source="https://github.com/pratik0207/todo-list-multi-container" \
      org.opencontainers.image.licenses="MIT"

# Copy custom Nginx configuration and static frontend assets
COPY frontend/nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY frontend/public/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
