class PaymentGateway
  def self.charge(simulate: "success")
    simulate == "fail" ? false : true
  end
end
