# How to be free of VCR

## Introduction

A time ago, I used [AWS Ruby SDK](https://aws.amazon.com/sdk-for-ruby/) to create a method to download files from S3, and I was introduced to [Aws::ClientStubs](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/ClientStubs.html), which is amazing, and opened my mind about how to test integration with external APIs!

Before discovering `Aws::ClientStubs`, I was wondering how to test the new code, in a integrated way, using the gem [VCR](https://github.com/vcr/vcr).

For those who don't know, [my most popular post](./2019-07-08-10_tips_to_help_using_the_VCR_gem_in_your_ruby_test_suite.md) is related to VCR, so this would be the default way for me to test it.

## How Aws::ClientStubs works

Now, let me show how `Aws::ClientStubs` works and why I liked it!

Suppose that there is the following method to download a file from S3, which returns a tempfile with the file content:

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

With `Aws::ClientStubs`, it's possible to test it like this (I'm using RSpec):

```ruby
require 'rspec'

describe S3Downloader do
  describe '#download' do
    it 'fetches the S3 object to a tempfile' do
      # setup
      s3_client = Aws::S3::Client.new(stub_responses: true)

      file_body = 'test'
      s3_client.stub_responses(:get_object, body: file_body)

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

It's so good that this library provides a way to stub the requests!

## How would I test it without Aws::ClientStubs

Without `Aws::ClientStubs`, it would be necessary to choose one of the following approachs to test it:

### 1. Using a valid S3 credential to download a file from S3 every time the test runs

Pros:
- It's the easy, because the test would use the same code as the production code.
- No mocks and stubs are necessary
- No VCR setup is necessary

Cons:
- The test would only pass if it was connected to the Internet
- The test would depend on the state of the bucket and on the availability of S3
- The test would be slow to run

### 2. Using the gem VCR

Pros:
- It would be possible to run the tests offline
- The test would run quickly

Cons:
- To record a VCR cassette, it would be necessary a valid S3 credential and internet connection
- The test setup and tear down would become a bit more complex, because it would ensure that there is a file on S3 to be downloaded, when recording the cassette
- If something change in the requests, maybe it would be necessary to record the VCR cassettes again. This can be hard to do if the test setup is not completely indempotent

### 3. Use mock/stub

Pros:
- It would be possible to run the tests offline
- The test would run quickly
- It woudn't be necessary to have a valid S3 credential to run the test
- The setup and tear down wouldn't require uploading or deleting the file from S3

Cons:
- A test with stubs and mocks, if made in a wrong way, is useless, example:

```ruby
describe S3Downloader do
  describe '#download' do
    it 'fetches the S3 object to a tempfile' do
      # setup
      s3_client = Aws::S3::Client.new

      allow(s3_client).to receive(:get_object).and_return("object")

      # verify
      expect(s3_client.get_object).to eq("object")
    end
  end
end
```

In this case, we have no guarantee that the return of `Aws::S3::Client#get_object` is the same as the stubbed one.

Even if we compare and be sure that it is correct, if the API or method change their response, the test would be stuck with the stub response and it could be noticed only in production!


## Why I liked the approach of Aws::ClientStubs

When we are using a client of an external API and it has a test class/helper, we believe that we can trust on its stubbed responses.

If the API response changes, we expect that the new version of the gem updates also the response of the `ClientStub`.


TODO:
- explicar como implementar algo parecido na sua propria gem
- explicar como garantir que o ClientStub esta respondendo exatamente igual a API


## A simple comparison of each approach

The following table sumarize the pros and cons of each approach:

| Criteria                 | No mocks/stubs, No VCR | VCR   | Mocks/stubs | Client stub |
| ------------------------ | ---------------------- | ----- | ----------- | ----------- |
| Easy?                    | ✅                     | 🚫    | 💁‍♂️       | ✅          |
| Works offline ?          | 🚫                     | ✅    | ✅          | ✅          |
| Free of S3 state?        | 🚫                     | 💁‍♂️    | ✅          | ✅          |
| Free of S3 availability? | 🚫                     | 💁‍   | ✅          | ✅          |
| Fast?                    | 🚫                     | ✅    | ✅          | ✅          |
| Testing for real?        | ✅                     | ✅    | 🚫          | ✅          |

TODOs:
- mostrar como isso funciona
- dar exemplo de como fazer em uma lib(client) propria
