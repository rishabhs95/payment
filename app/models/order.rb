class Order < ActiveRecord::Base
  belongs_to :cart
  has_many :transactions, :class_name => "OrderTransaction"
  
  attr_accessor :card_number, :card_verification
  
  validate :validate_card, :on => :create
  
  def purchase
    response = GATEWAY.purchase(price_in_cents, credit_card, purchase_options) rescue false
    unless response
      self.errors.add("base", "Unable to make payment")
      return false
    end

    if response.success? == false   
      errors[:base] << response.message
      return false       
    end 

    transactions.create!(:action => "purchase", :amount => price_in_cents, :response => response)
    cart.update_attribute(:purchased_at, Time.now) if response.success?
    response.success?
  end
  def authorize

    response = GATEWAY.authorize(price_in_cents, credit_card, purchase_options) rescue false   
    puts "*******************"   
    puts response.inspect    
    puts "************************"
    unless response   
      errors[:base] << "Unable to authorize credit card"
      return false
    end 
      
    
    if response.success? == false   
      if response.avs_result['code'] != "P"  
        errors[:base] << response.avs_result['message']
        return false   
      end
      errors[:base] << response.message
      return false       
    end        

    transactions.create!(:action => "authorize", :amount => price_in_cents, :response => response)
    cart.update_attribute(:purchased_at, Time.now) if response.success?
    response.success?



  end
  def price_in_cents
    (cart.total_price*100).round
  end
 
  private


  def purchase_options
    {
      :ip => ip_address,
      :billing_address => {
        :name     => "Ryan Bates",
        :address1 => "123 Main St.",
        :city     => "New York",
        :state    => "NY",
        :country  => "US",
        :zip      => "10001"
      }
    }
  end 

  def validate_card
    unless credit_card.valid?
      credit_card.errors.full_messages.each do |message|
        errors[:base] << message
      end
    end
  end

  def credit_card
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :brand               => card_type,
      :number             => card_number,
      :verification_value => card_verification,
      :month              => card_expires_on.month,
      :year               => card_expires_on.year,
      :first_name         => first_name,
      :last_name          => last_name
    )
  end
end
