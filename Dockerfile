
---

### 🔹 `Dockerfile`

```Dockerfile
FROM nginx:alpine
COPY app/nginx/index.html /usr/share/nginx/html/index.html
