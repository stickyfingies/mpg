# syntax=docker/dockerfile:1

FROM node:23

WORKDIR /app

COPY . .

WORKDIR /app/server
RUN npm install
ENV NODE_ENV production
EXPOSE 8080

CMD ["npm", "start"]