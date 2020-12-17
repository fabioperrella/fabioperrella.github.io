---
layout: post
title: How to be free of VCR
---

A few weeks ago, I used AWS Ruby SDK to implement something with S3 and I was
introduced to `Aws::ClientStubs`, which is amazing!

Before that, I was wondering how to record a VCR, to test in a integrated way,
the code that I have done.

For the ones who don't know, [my most popular post](./2019-07-08-10_tips_to_help_using_the_VCR_gem_in_your_ruby_test_suite.md)
is related to VCR, so this would be the natural way for me to test it.

Now, let me show how `Aws::ClientStubs` works!

Suppose that there is the following method to download a file from S3 which returns
a tempfile with the content of it:

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

TODOs:
- falar a vantagem e nao ter vcr
- mostrar como isso funciona
- dar exemplo de como fazer em uma lib(client) propria
