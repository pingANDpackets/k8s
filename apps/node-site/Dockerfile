FROM node:18-alpine
WORKDIR /usr/src/app
COPY package.json package-lock.json* ./
RUN npm install --production
COPY server.js .
ENV PORT=8080
EXPOSE 8080
CMD ["npm", "start"]
