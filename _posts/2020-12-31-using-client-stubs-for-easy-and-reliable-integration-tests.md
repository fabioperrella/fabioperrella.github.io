---
layout: post
title: Using client stubs for easy and reliable integration tests
---

A while ago, I used [AWS Ruby SDK](https://aws.amazon.com/sdk-for-ruby/) to create a method to download files from S3, and I was introduced to [Aws::ClientStubs](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/ClientStubs.html), which is amazing, and it opened up my mind on how to test external APIs with a more integrated approach!

Before discovering `Aws::ClientStubs`, I wondered how to test this new code, maybe I could use the gem [VCR](https://github.com/vcr/vcr).

For those of you who haven't read my [previous post](./2019-07-08-10_tips_to_help_using_the_VCR_gem_in_your_ruby_test_suite.md), the most popular one is related to VCR, which would be my default way to test it.

## How to use Aws::ClientStubs

Supposing the following method to download a file from S3, which returns a temporary file with the file content:

```ruby
require 'aws-sdk-s3'

class S3Downloader
  def initialize(s3_client: Aws::S3::Client.new)
    @s3_client = s3_client
  end

  def download(key:, bucket:)
    tempfile = Tempfile.new

    @s3_client.get_object(
      response_target: tempfile,
      bucket: bucket,
      key: key
    )

    tempfile
  end
end
```

With `Aws::ClientStubs`, it's possible to test it like this (using RSpec):

```ruby
require 'rspec'

describe S3Downloader do
  describe '#download' do
    it 'fetches the S3 object to a tempfile' do
      # setup
      s3_client = Aws::S3::Client.new(stub_responses: true) # <---- look here!

      file_body = 'test'
      s3_client.stub_responses(:get_object, body: file_body) # <--- and here

      expect(s3_client).to receive(:get_object).and_call_original

      # exercise
      result = described_class
        .new(s3_client: s3_client)
        .download(key: 'any', bucket: 'bucket')

      # verify
      expect(result.read).to eq(file_body)
    end
  end
end
```

## How would I test it without Aws::ClientStubs

Without `Aws::ClientStubs`, it would be necessary to choose one of the following approaches to test it:

### 1. Using a valid S3 credential to download a file from S3 every time you run the test

Pros:
- It's the easiest approach, because the test would use the same code as the production code.
- No mocks and stubs are necessary
- No VCR setup is necessary
- It's a reliable test since it's integrated with the real API

Cons:
- The test would only pass if connected to the Internet
- The test would depend on the state of the bucket and on the availability of S3
- The test would be slow to run

### 2. Using the gem [VCR](https://github.com/vcr/vcr)

Pros:
- It would be possible to run the tests offline
- The test would run quickly
- It's a reliable-ish test since it's integrating with the real API when recording the cassette

Cons:
- To record a VCR cassette, it would be necessary a valid S3 credential and being connected to the Internet
- The test setup and tear down would become a bit more complex, because it would have to ensure there is a file on the S3 bucket to be downloaded, when recording the cassette
- If the API changes its interface, the test may not notice it, since it would be using an older recorded cassette version of it
- The test may fail if the payload or query string changes. This would be good to acknowledge that something has changed, sending data to the API, but it would be bad because it may be hard to fix it, and it can result in flaky tests

### 3. Using a mock/stub

Pros:
- It would be possible to run the tests offline
- The test would run quickly
- It wouldn't be necessary to have a valid S3 credential to run the test
- The setup and tear down wouldn't require uploading or deleting the file from S3

Cons:
- A test with stubs and mocks, when done inaccurately, could be testing nothing, example:

```ruby
describe S3Downloader do
  describe '#download' do
    it 'fetches the S3 object to a tempfile' do
      # setup
      s3_client = Aws::S3::Client.new

      allow(s3_client).to receive(:get_object).and_return("object") # <-- this is not so good

      # verify
      expect(s3_client.get_object).to eq("object")
    end
  end
end
```

In this case, there is no guarantee that the return of `Aws::S3::Client#get_object` is the same as the stubbed one.

Even if we compare and we are sure that it is correct, if the API or method change their response, the test would be stuck with the stubbed response and this could be noticed only in production!


## Why I like the approach of Aws::ClientStubs

When we use a client of an external API and it has a test class/helper, we believe that we can trust on its stubbed responses.

If the API response changes, we expect that the new version of the gem updates also the response of the `ClientStub`.

## How to implement a Client Stub in your client gem

Suppose your gem has a method to retrieve a list of orders:

```ruby
client = YourClient.new
client.list_orders
=> {
  "orders" : [
    {
      "id": 1,
      "sku": "XYZ12",
      "quantity": 3,
      "customer_id": 55
    },
    {
      "id": 2,
      "sku": "WZA32",
      "quantity": 1,
      "customer_id": 44
    },
  ]
}
```

Then, you can add an option to stub the response:

```ruby
client = YourClient.new(stub_response: true)
orders = client.list_orders
```

This is a simple way to implement it on the gem side:

```ruby
class YourClient
  def initialize(stub_response: false)
    @stub_response = stub_response
  end

  def list_orders
    return YourClientStubbed.new.list_orders if @stub_response

    ## the real implementation
  end
end

class YourClientStubbed
  def list_orders
    {
      "orders" => [
        {
          "id" => 1,
          "sku" => "SKU1",
          "quantity" => 1,
          "customer_id" => 1
        },
        {
          "id" => 2,
          "sku" => "SKU2",
          "quantity" => 2,
          "customer_id" => 2
        },
      ]
    }
  end
end
```

To ensure that your stubbed method returns the same content as the original one, it's possible to create a test as the following:

```ruby
require 'rspec'

describe YourClientStubbed do
  def create_order(**args)
    post("/orders", args)
  end

  describe "#list_orders" do
    it "returns the same structure as the real api", :vcr do
      stubbed_orders = YourClientStubbed.new.list_orders

      stubbed_orders.each do |stubbed_order|
        create_order(
          id: stubbed_order.id,
          sku: stubbed_order.sku,
          quantity: stubbed_order.quantity,
          customer_id: stubbed_order.customer_id
        )
      end

      real_orders = YourClient.new.list_orders

      expect(stubbed_orders).to eq(real_orders)
    end
  end
end
```

With that, when a new attribute is added to the API, the test would break.

For this test, I would recommend using VCR to test it against the real API, because it must be a strong test to ensure the stubbed response is valid!

I wrote another article with more details of VCR gem usage [here](./2019-07-08-10_tips_to_help_using_the_VCR_gem_in_your_ruby_test_suite.md).


## A simple comparison of each approach

The following table summarizes the pros and cons of each approach:

| Criteria                 | No mocks/stubs, No VCR | VCR   | Mocks/stubs | Client stub |
| ------------------------ | ---------------------- | ----- | ----------- | ----------- |
| Easy?                    | ✅                     | 🚫    | 💁‍♂️       | ✅          |
| Works offline ?          | 🚫                     | ✅    | ✅          | ✅          |
| Free of S3 state?        | 🚫                     | 💁‍♂️    | ✅          | ✅          |
| Free of S3 availability? | 🚫                     | 💁‍   | ✅          | ✅          |
| Fast?                    | 🚫                     | ✅    | ✅          | ✅          |
| Testing for real?        | ✅                     | 💁‍    | 🚫          | ✅          |


## Conclusion

When you use a client of an external API, such as [AWS Ruby SDK](https://aws.amazon.com/sdk-for-ruby/), take a look on its docs to find out if there is something similar to a `ClientStub` and use it in your tests!

If you are a contributor of an API client gem, think about adding a `ClientStub` to help the users to create their tests!

Thanks @leandro_gs for reviewing it!
