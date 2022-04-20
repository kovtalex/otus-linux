FROM node:14-alpine

WORKDIR /app
COPY . .
RUN yarn
RUN yarn build

CMD ["sh", "-c", "cp -Rf /app/build/* /static"]

