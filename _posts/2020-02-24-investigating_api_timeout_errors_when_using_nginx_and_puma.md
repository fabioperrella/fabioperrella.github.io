---
layout: post
title: Investigating API timeout errors (when using Nginx and Puma)
---

On Ruby on Rails applications, a very common pattern is to [use Nginx as the
reverse proxy](http://nginx.org/en/docs/http/ngx_http_upstream_module.html) and
[Puma](https://puma.io/) as the application server.

One day, I was investigating a problem reported by the support team that
sometimes a page was not being rendered correctly, showing an unexpected
error.

This page gets the data from an API of another application and it seemed this
API was having some problem.

First, I tried to see the most recent API errors on [Sentry](https://sentry.io/) which
is the error monitoring tool that we use and I couldn't find anything relevant.

We also use [Newrelic](https://newrelic.com), which provides a lot of information
about the errors and I couldn't find anything too.

Then I impersonated into a customer account where I could reproduce the error.

I noticed the request was taking too much to complete, so it seemed a timeout
in somewhere, but I was curious why I wasn't finding errors related to it in
the API's Sentry page.

I remembered that Nginx has its access and error logs, so I looked to see what was
going on.

When I opened the error log, I could find all the errors that I was searching for!

```
...
2020/01/30 14:05:24 : upstream timed out (110: Connection timed out) while reading response header from upstream, client: 10.32.32.248, server: ~^app-name\..*\.company\.com\.br$, request: "POST /some_route/0000000066410219 HTTP/1.1", upstream: "http://unix:/var/www/app-name/tmp/sockets/app-name.sock/some_route/0000000066410219"
2020/01/30 14:05:27 : upstream timed out (110: Connection timed out) while reading response header from upstream, client: 10.32.32.249, server: ~^app-name\..*\.company\.com\.br$, request: "POST /some_route/0000000066410862 HTTP/1.1", upstream: "http://unix:/var/www/app-name/tmp/sockets/app-name.sock/some_route/0000000066410862"
...
```

Then I understood the problem! The request to Puma was timing out on Nginx, but
**it wasn't an error on the application and this is why I couldn't find anything
on Sentry**!

In the next days, we worked to improve/limit the API's response time (the problem
was in another API which was slow and we chose to set a smaller timeout for it)
and I after the deploy it, I started to check the error logs every day to see if
it had improved.

But at this point, when I stopped to check the logs, we could have the same
problem again and no one would notice before a customer reports the problem.

Actually we didn't have time to improve it and we are in the same situation
until today.

I chose to write this post to:

- expose the problem
- get feedback on how the people deal with these problems

I have an idea of how improving the observability, which is to measure the
response time on the API and
[report the failure to Sentry](https://docs.sentry.io/clients/ruby/#reporting-failures)
if it is longer than the expected.

I would prefer to send it to Sentry because it sends us a notification of every
new error that is happening on the application, and I'm used to reading these
emails to see if there is something new going on.

So my tip is to check the Nginx logs, it can give us some important
information!
