.PHONY: deploy_all

deploy_all: build deploy

# Build

build: build_nginx build_php-fpm

build_nginx:
	cd nginx && docker build -t kovtalex/nginx:v2 .

build_php-fpm:
	cd php-fpm && docker build -t kovtalex/php-fpm:v1 .


# Push

push: push_nginx push_php-fpm 

push_nginx:
	docker push kovtalex/nginx:v2

push_php-fpm:
	docker push kovtalex/php-fpm:v1


# Deploy

deploy:
	docker-compose up -d

# Destroy

destroy:
	docker-compose down

