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

require 'rspec'

describe YourClientStubbed do
  describe "#list_orders" do
    it "returns the same structure as the real api", :vcr do
      stubbed_orders = YourClientStubbed.new.list_orders

      # create_order(id: 1, sku: "SKU1", quantity: 1, customer_id: 1)
      # create_order(id: 2, sku: "SKU2", quantity: 2, customer_id: 2)
      real_orders = YourClient.new.list_orders

      expect(stubbed_orders).to eq(real_orders)
    end
  end
end
