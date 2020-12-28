require 'aws-sdk-s3'
require 'rspec'

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
