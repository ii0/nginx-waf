# Create a Web Application Firewall (WAF) with NGINX, OpenResty and Apility.io services

# What is Apility.io?

[Apility.io][apilityio-site-url] is a set of lists like IP, domains and emails. Some of them marked as 'abusers' by several groups and initiatives of users and communities, and others used to filter out potential abusers.

Apility.io can be defined as a Look up as a Service for developers and product companies that want to know in realtime if their existing or potential users have been classified as 'abusers' by one or more of these lists.

Automatic extraction processes extracts all the information in realtime, keeping the most up to date data available, saving yourself the hassle of extract and update regularly all these lists and the data.

Apility.io's documentation can be found at [apility.io/docs/index.html][apilityio-docs-url]. You can also read a post in our blog about how we built the [NGINX WAF with Openresty][apilityio-blog] step by step.

# How to use this image

This image is an example of how to integrate Apility.io API with NGINX to build a Web Application Firewall to secure the access to resources like web applications, API and static content.

These scripts build a Docker image with NGINX enabled with OpenResty to use the scripting language Lua. So every time a request is made to the NGINX service a Lua script asks to Apility.IO API about how reputable is the IP of origin. To reduce latency and the number of requests to Apility.io, there is a cache with a Time To Live for the objects.

## The base image

This image is built on top of Ubuntu Xenial image that is configured for correct use within Docker containers. The image contains:

[OpenResty][openresty-site-url] is a full-fledged web platform by integrating the standard Nginx core, LuaJIT, many carefully written Lua libraries, lots of high quality 3rd-party Nginx modules, and most of their external dependencies. It is designed to help developers easily build scalable web applications, web services, and dynamic web gateways.

[Lua][lua-site-url] is a powerful, efficient, lightweight, embeddable scripting language. It supports procedural programming, object-oriented programming, functional programming, data-driven programming, and data description.

[NGINX][nginx-site-url] is a web server which can also be used as a reverse proxy, load balancer and HTTP cache. Nginx is free and open source software, released under the terms of a BSD-like license.

**lua-resty-http** is a Lua library to perform http requests, used by the file **filter.lua** that implements the caching logic, combined with the nginx.conf configuration file and the default.conf (nginx.waf.sample.conf) example.

## Configuration files and folder

The configuration files and folders allow an easy customization of the image at build time and runtime.

### Dockerfile

Docker can build images automatically by reading the instructions from a Dockerfile. A Dockerfile is a text document that contains all the commands a user could call on the command line to assemble an image. This Dockerfile performs the following actions:

* Build and install Openresty (NGINX, LUA, libraries and modules).
* Install resty http library
* Enable NGINX service

This is the place where you can play your magic with Docker, if you need it.

#### nginx.conf

The NGINX configuration file. This file contains the configuration needed to enable Lua and the caching objects to NGINX.

#### nginx.waf.sample.conf

The NGINX default configuration file. It's copied into **/etc/nginx/conf.d/** and renamed as **default.conf**. This file contains the configuration needed to add the access filter when serving content. The file has three different examples:

* How to serve static content. The content inside the 'static' folder.
* How to secure the proxy to external static content. The static content is an Amazon S3 bucket where the Apility.io API docs website is hosted.
* How to secure the proxy to an API service. The API service is hosted in [mockbin.org](http://mockbin.org)

### project folder

The project folder contains the static folder with the index.html sample.

## How to build the image

To build the image, execute this command:

```shell
$ docker build -t nginx-waf .
```

The image nginx-waf will be created and uploaded to your local Docker registry.

## Start NGINX

### Apility.IO parameters

To service needs the following parameters:

* APILITYIO_URL: The url where the API listens. By default, **https://api.apility.net**
* APILITYIO_LOCAL_CACHE_TTL: Time to Live in seconds of the local cache of IP.
* APILITYIO_API_KEY: User API Key. If not provided, the IP is checked against all blacklists with the limits for anonymous users. You can get an API KEY for free at [dashboard.apility.io](https://dashboard.apility.io/#/register)

**Note:** Registered users can choose what blacklists to check the IP, define their own lists and implement multiple complex quarantine logic.

### Run command

You can download the image from Docker Hub, or built it. To run the image execute this command:

```shell
$ docker run -d -t -i \
     -e APILITYIO_URL=https://api.apility.net \
     -e APILITYIO_LOCAL_CACHE_TTL=SECONDS \
     -e APILITYIO_API_KEY=USER_API_KEY \
     -p 80:80 \
     --name nginx-waf \
     apilityio/nginx-waf
```

### nginx config files

The Docker tooling installs its own nginx.conf. If you want to directly override it, you can replace it in your own Dockerfile or via volume bind-mounting.

That `nginx.conf` has the directive `include /etc/nginx/conf.d/*.conf;` so all nginx configurations in that directory will be included. The NGINX default configuration file it's copied into **/etc/nginx/conf.d/** and renamed as **default.conf**. This file contains the configuration needed to add the access filter when serving content. This is the file you should modify to adapt to your project needs.

You can override that `default.conf` directly or volume bind-mount the `/etc/nginx/conf.d` directory to your own set of configurations:

```shell
$ docker run -d -t -i \
     -e APILITYIO_URL=https://api.apility.net \
     -e APILITYIO_LOCAL_CACHE_TTL=SECONDS \
     -e APILITYIO_API_KEY=USER_API_KEY \
     -v /my/custom/conf.d:/etc/nginx/conf.d \
     -p 80:80 \
     --name nginx-waf \
     apilityio/nginx-waf
```

### Project files

You will probably need more files to compose your project. You should add them via volume bind-mounting. For example the project `sample` as follows:

```shell
$ docker run -d -t -i \
     -e APILITYIO_URL=https://api.apility.net \
     -e APILITYIO_LOCAL_CACHE_TTL=SECONDS \
     -e APILITYIO_API_KEY=USER_API_KEY \
     -v /my/custom/conf.d:/etc/nginx/conf.d \
     -v /my/custom/sampleproject.d:/sampleproject.d \
     -p 80:80 \
     --name nginx-waf \
     apilityio/nginx-waf
```


### Show logs

Logs are dumped to syslog.

```shell
$ docker logs -f nginx-waf
```

## Test service

### Obtain the private IP of the service in the container

Find out the ID of the container that you just ran:

```shell
$ docker ps
```

Once you have the ID, look for its IP address with:

```shell
$ docker inspect -f "{{ .NetworkSettings.IPAddress }}" <ID>
```

This is the IP to use for testing.

### NGINX service

#### How the filter service works

For each request made to NGINX, the LUA script **filter.lua** will perform an API request to Apility.io to check if the IP belongs to any blacklists. If so, then NGINX will return a HTTP_FORBIDDEN code.

To boost the performance **filter.lua** implements a local cache to decrease the number of requests made to Apility.io API.The Time to Live in this cache is configurable as described above with the parameter APILITYIO_LOCAL_CACHE_TTL.

NGINX listens at port 80. You can test three different services described above:

#### Secure access to external static content

Open a browser and point it to:

```shell
http://NetworkSettings.IPAddress/s3/
```

The Apility.io API docs site should open in this url. Under the hoods NGINX is configured to serve the content located at Amazon S3.

#### Secure access to local static content

Open a browser and point it to:

```shell
http://NetworkSettings.IPAddress/static/
```

A very simple "Hello World" site should open in this url. NGINX is configured to serve the content located in the static folder.

#### Secure access to external API (API Gateway)

Open a browser and point it to:

```shell
http://NetworkSettings.IPAddress/mockbin/
```

[mockbin.org](http://mockbin.org) is a simple API test site. NGINX proxies the requests to the mockbin endpoint.


# User Feedback

## Issues

If you have any problems with or questions about this image, please contact us through a [GitHub issue][github-new-issue].

## Contributing

You are invited to contribute new features, fixes, or updates, large or small; we are always thrilled to receive pull requests, and do our best to process them as fast as we can.

Before you start to code, we recommend discussing your plans through a [GitHub issue][github-new-issue], especially for more ambitious contributions. This gives other contributors a chance to point you in the right direction, give you feedback on your design, and help you find out if someone else is working on the same thing.

[apilityio-site-url]: https://apility.io
[apilityio-docs-url]: https://docs.apility.io
[openresty-site-url]: https://openresty.org
[lua-site-url]: https://www.lua.org
[nginx-site-url]: https://nginx.org
[apilityio-blog]: https://apility.io/2018/01/20/nginx-waf-openresty/
[github-new-issue]: https://github.com/apilityio/nginx-waf/issues/new/
