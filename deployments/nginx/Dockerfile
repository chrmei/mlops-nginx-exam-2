FROM nginx:alpine

RUN apk add --no-cache apache2-utils

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/nginx.conf
COPY certs/nginx.crt /etc/nginx/certs/nginx.crt
COPY certs/nginx.key /etc/nginx/certs/nginx.key
COPY .htpasswd /etc/nginx/.htpasswd

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]

