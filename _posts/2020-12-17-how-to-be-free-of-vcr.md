# How to be free of VCR

A few weeks ago, I used [AWS Ruby SDK](https://aws.amazon.com/sdk-for-ruby/) to implement something with S3 and I was introduced to `Aws::ClientStubs`, which is amazing!

Before that, I was wondering how to test the new code, in a integrated way, using the gem [VCR](https://github.com/vcr/vcr).

For the ones who don't know, [my most popular post](./2019-07-08-10_tips_to_help_using_the_VCR_gem_in_your_ruby_test_suite.md) is related to VCR, so this would be the default way for me to test it.

Now, let me show how `Aws::ClientStubs` works and why I liked it!

Suppose that there is the following method to download a file from S3 which returns a tempfile with the content of the file:

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
      result = described_class.new(s3_client: s3_client).download(key: 'any', bucket: 'bucket')

      # verify
      expect(result.read).to eq(file_body)
    end
  end
end
```

It's so good that the library provides a way to stub the requests! Without that it would be necessary to choose one of the following approachs to test it:

### 1. Use valid credentials and download a file from S3 every time we run the test

Pros:
- It's the easier way do it, because the test would use the same code as in production.
- No mocks and stubs are necessary
- No VCR setup is necessary

Cons:
- The test would only pass if connected to the Internet
- The test would depend on the state of the bucket and on the availability of S3
- The test would be slow to run

### 2. Use the gem VCR

Pros:
- It would be possible to run the tests offline
- The test would run quickly

Cons:
- To record a VCR cassette, it would be necessary a valid credential
- The test setup and tear down would become a bit more complex, because it would ensure that there is a file on S3 to be downloaded
- If something change in the requests, maybe it would be necessary to record the VCR cassettes again

### 3. Use mock/stub

Pros:
- It would be possible to run the tests offline
- The test would run quickly
- It woudn't benecessary having valid credentials to run the test
- The setup and tear down wouldn't require uploading or deleting the file from S3

Cons:
- If the stub is done wrong, it would be possible that the test would be testing nothing, example:

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



TODOs:
- falar a vantagem e nao ter vcr
- mostrar como isso funciona
- dar exemplo de como fazer em uma lib(client) propria
