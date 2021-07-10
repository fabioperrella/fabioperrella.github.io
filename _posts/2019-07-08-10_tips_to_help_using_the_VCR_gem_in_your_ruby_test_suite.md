---
layout: post
title: 10 tips to help using the VCR gem in your Ruby test suite
permalink: 10_tips_to_help_using_the_VCR_gem_in_your_ruby_test_suite.html
---

The original post, in Portuguese, was published [here](https://imasters.com.br/ruby/10-dicas-para-facilitar-o-uso-da-gem-vcr-nos-testes-da-sua-app-ruby). (I procrastinated to translate it to English almost 1 year!)

The gem [VCR](https://github.com/vcr/vcr) is a good choice to do integrated tests in Ruby apps. It can be used in other languages too, but it will be not covered in this post.

It let us automate the process of stubbing the web requests through the gem [Webmock](https://github.com/bblimke/webmock) (or other similar). In order to do it, it records *cassette files* with all the HTTP requests and responses to external APIs. By doing this, it allows us to execute the test suite fastly and not depending on their state and disponibility of these APIs.

However, when a test suite starts to get bigger, it is necessary to care about some things to help on the maintenance and avoid turning into a nightmare.

I will list some tips and tricks to accomplish it.

The examples are using the gem [rspec](https://github.com/rspec/rspec) in a [rails](https://rubyonrails.org/) project, but VCR can be used with other frameworks, like [sinatra](https://github.com/sinatra/sinatra) with [minitest](https://github.com/seattlerb/minitest).

## 1. Setup VCR to generate the cassette names automatically

To avoid using the block `VCR.use_cassette` in all scenarios and besides that, having to name all the cassettes, when using with rspec, it is possible to mark each scenario that will use VCR with the symbol `:vcr`, as follows:

```ruby
describe SomeApi do
  it 'creates the product', :vcr do
    # test...
  end
end
```

To do this, it is necessary to use the configuration below in VCR:
```ruby
VCR.configure do |c|
  c.configure_rspec_metadata!
end
```

By doing this, it will be created a cassette file according to the current context, for example:
`spec/fixtures/vcr_cassettes/SomeApi/creates_the_product.yml`

More details in [rspec docs](https://relishapp.com/vcr/vcr/v/2-4-0/docs/test-frameworks/usage-with-rspec-metadata).

## 2. Setup VCR to record the cassettes just once

The VCR gem has some available record modes. It is recommended to use the mode `:once` which will record the cassette only if it does not exist.


```ruby
VCR.configure do |c|
  vcr_mode = :once
end
```

After the file is recorded, if this scenario tries to call the APIs with different parameters or try to call other APIs, the test will break, as follows:

```
VCR::Errors::UnhandledHTTPRequestError:

================================================================================
An HTTP request has been made that VCR does not know how to handle:
 GET http://someapi.com?lala=popo
 Body:

VCR is currently using the following cassette:
 - /home/fabioperrella/workspace/some-app/spec/fixtures/vcr_cassettes/some_api/some_vcr_.yml
   - :record => :once
   - :match_requests_on => [:method, :uri, :body]
```

The advantage of using this way, is to be sure that the cassettes are enough to run all the tests offline and allow us to do the next tip, which is disallowing external requests!

## 2.1 Ignore the headers to match the cassete

I strongly recommend to use this configuration

```ruby
VCR.configure do |c|
  c.match_requests_on: %i[method uri body]
end
```

This will avoid errors when some header changes. Once a time, I saw a header changing when running ruby in Mac OS or Linux!

The default configuration is only `[method, uri]`, but in my opinion it is important to compare the body too!

More details in [rspec docs](https://relishapp.com/vcr/vcr/v/1-6-0/docs/cassettes/request-matching)

## 3. Disallow external requests

Be able to run the test suite offline, not caring about the state and disponibility of external APIs is our goal!

Disallowing external requests is already the default behavior of VCR, and can be changed using the config `allow_http_connections_when_no_cassette`, but don't do it!

Remember it is required to do the previous tip to achieve this successfully.

## 4. Have a way to record the cassettes again easily

Sometimes, it is necessary to change a test scenario (or the source code) which already has a cassette recorded and can be necessary to record it again.

The trivial way would be deleting the current file and recording it again.

But it is possible to use the following configuration, which will provide an environment variable to indicate that the cassette should be recorded again.

```ruby
VCR.configure do |c|
  vcr_mode = ENV['VCR_MODE'] =~ /rec/i ? :all : :once

  c.default_cassette_options = {
    record: vcr_mode,
    match_requests_on: %i[method uri body]
  }
end
```

By doing this, it is possible to run a scenario as following:
```
VCR_MODE=rec bundle exec rspec spec/some_class_spec.rb:30
```

But **be careful**, if you run all the suite with this ENV, it will record all the cassettes!


## 5. Use the VCR.current_cassette.file to know where the cassette file is stored

Using the symbol `:vcr` to enable the VCR in a scenário help us in the task of naming and organizing the cassette files, but it turns difficult when we want to know where the cassette file is.

To help with it, it is possible to use the method bellow:
```ruby
it 'does somethid', :vcr do
  puts VCR.current_cassette.file
  # test ...
end
```

Extra tip: have a snippet in you text editor to generate this line. For example I have [one for it](https://github.com/fabioperrella/dotfiles/blob/master/sublime/current_vcr.sublime-snippet).

## 6. Be careful with the *sequences* in factories

When using the gem [factory_bot](https://github.com/thoughtbot/factory_bot), it is possible to create [sequences](https://github.com/thoughtbot/factory_bot/blob/master/GETTING_STARTED.md#sequences) to generate sequential values for the attributes.

Depending on the order the tests run, these values will be different and because of it, it can break some scenarios with VCR because the payload or the query string of a request will be different comparing with the recorded one.

It is a good practice to run the suite in a random order, to detect when a scenario depends on another one (it should be indepentent), because of it, in scenarios using VCR and a factory, it is recommended to set fixed values in attributes which would be generated by a sequence as following:

```ruby
#spec/factories/cars.rb
FactoryBot.define do
  factory :product do
    description "some product"
    sequence(:sku) { |n| "SKU-#{n}" }
  end
end

#spec/car_api_spec.rb
describe CartCreation do
  it "add the product to the cart", :vcr do
    product = build(:product, sku: 'SKU-33') # if not setting sku, the VCR can break!
    response = CartCreation.create(product)

    expect(response).to eq(:ok)
  end
end
```

## 7. Always let the scenario ready to be re-recorded

Sometimes, it is necessary to re-record some cassettes. If the setup of the scenario is not prepared, it can turn into a difficult task.

For instance, testing an API which will delete a resource in the server:

```ruby
it 'deletes the resource', :vcr do
  resource_id = 40 # ID wich exists in some place

  response = SomeApi.delete(resource_id)

  expect(response).to eq(:o)
end
```

In the first time runnnin the scenario, the cassette will be recorded and it will work.

But when something changes, when trying to record the cassette again, the resource with id 40 will not exist anymore and the execution will fail!

One option to let this scenario [idempotent](https://en.wikipedia.org/wiki/Idempotence) is creating the resource in the setup as following:

```ruby
it 'deletes the resource', :vcr do
  # setup
  resource = SomeApi.create

  # exercise
  response = SomeApi.delete(resource.id)

  # verify
  expect(response).to eq(:ok)
end
```

## 8. Be careful with caches and the execution order

A good practice is to run the tests in random order to force the scenarios do not depend on the others.

With Rspec, it is possible to do it with the following configuration:

```ruby
RSpec.configure do |config|
  config.order = 'random'
end
```

Using VCR as suggested in this article, with the configurations `record: :once` and with `allow_http_connections_when_no_cassette=false`, any request made with a different URL, method or body than it was recorded in the cassette, will break the test.

A common scenario is caching an authentication token API, for example.

With the cache turned on, the first cassette recorded will have the request to get the token, but the others no (because it will use from the cache), like this:

```
# first cassette
POST http://some-api.com/authentication
GET http://some-api.com/users?token=1234

# second cassette
GET http://some-api.com/products?token=1234
```

When running the tests in random order, if the test with the second cassette runs first, it will break because it will try to do a request to create the token which is not recorded.

Turning off the token cache, the cassettes would be recorded like this:

```
# first cassette
POST http://some-api.com/authentication
GET http://some-api.com/users?token=1234

# second cassette
POST http://some-api.com/authentication
GET http://some-api.com/products?token=3456
```

With this strategy, it is possible to run the scenarios in any order!

## 9. Normalize (replace) the API URLs on cassettes

To avoid the tests with VCR brake when a URL of an API changes, it is possible to use the following configuration to normalize the URLs:

```ruby
VCR.configure do |c|
  c.filter_sensitive_data("<SOME_API>") { 'some-api.com' }
end
```

If using environment variables to configure these URLs, we can do it in a smarter way:
```ruby
VCR.configure do |c|
  %w[
    SOME_API_URL
    OTHER_API_URL
  ].each do |key|
    c.filter_sensitive_data("<#{key}>") { ENV[key] }
  end
end
```

By doing this, it is easy to use a different URL (or port) in the development environment, for example, if running with Docker.

## 10. Ignore the cassette diffs in merge requests

Whenever we create a merge request, we need to take care to not let the diff so huge to help the review process by the team.

In some situations, a little change in the source-code can bring a lot of changes in the cassettes, because they needed to be recorded again.

To avoid this noise in the diffs, it is possible to use the file [.gitattributes](https://git-scm.com/docs/gitattributes) to hide them. The majority of the git hosts (such as github, gitlab) can recognize it:

```
* text=auto

spec/fixtures/vcr_cassettes/**/* -diff
```

In this case, the diff of the files will be hidden in MRs.

**Attention**: the diff will be hidden also in all git clients, for example, `tig` or `gitx`, but it is possible to remove (or comment) this file temporarily to see the diff in the local environment, when necessary.

## Wrapping Up

I hope these tips and tricks can help the devs using tests with VCR, which is a great tool in my opinion!

If you have any comments or suggestions, please leave a comment below.

See you next!
