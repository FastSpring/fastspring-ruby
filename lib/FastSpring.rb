require 'httparty' unless defined?(HTTParty)
require 'active_support/builder' unless defined?(Builder)

class FastSpring
  @test_mode = false
  
  def test_mode?
    @test_mode
  end
  
  def test_mode=(mode)
    @test_mode = true
  end
  
  def initialize(store_id, api_username, api_password)
    @auth = { :username => api_username, :password => api_password }
    @store_id = store_id
  end
  
  def create_subscription(product_ref, referrer)
    url = "http://sites.fastspring.com/" <<  @store_id << "/product/" << product_ref << "?referrer=" << referrer;
    url = add_test_mode(url)
  end
  
  def get_subscription(subscription_ref)
    url = subscription_url(subscription_ref)
    
    options = { :basic_auth => @auth }
    response = HTTParty.get(url, options)
    
    if response.code == 200
      sub = parse_subscription(response.parsed_response.fetch('subscription'))
    else
      exception = FsprgException.new(response.code, nil)
      raise exception, "An error occurred calling the FastSpring subscription service", caller
    end
    
    sub
  end
  
  def update_subscription(subscription_update)
    url = subscription_url(subscription_update.reference)
    
    options = { :headers => { 'Content-Type' => 'application/xml' }, :body => subscription_update.to_xml, :basic_auth => @auth }
    response = HTTParty.put(url, options)
    
    if response.code == 200
      sub = parse_subscription(response.parsed_response.fetch('subscription'))
    else
      exception = FsprgException.new(response.code, nil)
      raise exception, "An error occurred calling the FastSpring subscription service", caller
    end
    
    sub
  end
  
  def cancel_subscription(subscription_ref)
    url = subscription_url(subscription_ref)
    
    options = { :basic_auth => @auth }
    response = HTTParty.delete(url, options)

    if response.code == 200
      sub = parse_subscription(response.parsed_response.fetch('subscription'))
    else
      exception = FsprgException.new(response.code, nil)
      raise exception, "An error occurred calling the FastSpring subscription service", caller
    end
    
    sub
  end
  
  def renew_subscription(subscription_ref)
    url = subscription_url(subscription_ref, { :postfix => "/renew" })

    options = { :basic_auth => @auth }
    response = HTTParty.post(url, options)

    if response.code != 201
      exception = FsprgException.new(response.code, response.parsed_response)
      raise exception, "An error occurred calling the FastSpring subscription service", caller
    end
  end
  
  private
  
  def subscription_url(reference, *options)
    url = "https://api.fastspring.com/company/#{@store_id}/subscription/#{reference}"
    
    unless options.nil? || options.length == 0
      opt = options[0]
      if opt.has_key?(:postfix)
        url = url << opt[:postfix]
      end
      if opt.has_key?(:params)
        params = opt[:params]
        if params.length > 0
          url = url << "?"
        end
        params.each do |param|
          url = url << param
        end
      end
    end
    
    url = add_test_mode(url)
  end
  
  def add_test_mode(url)
    if @test_mode
      if url.include? "?"
        url = url << "&mode=test"
      else
        url = url << "?mode=test"
      end
    end
    
    url
  end
  
  def parse_subscription(response)
    sub = FsprgSubscription.new
    
    sub.status = response.fetch('status', 'error')
    status_changed = response.fetch("statusChanged", nil)
    if not status_changed.nil?
      sub.status_changed = Date.parse(status_changed)
    end
    sub.status_reason = response.fetch("statusReason", nil)
    sub.cancelable = response.fetch("cancelable", nil)
    sub.reference = response.fetch("reference", nil)
    sub.test = response.fetch("test", nil)
    
    customer = FsprgCustomer.new;
    custResponse = response.fetch("customer")
    
    customer.first_name = custResponse.fetch("firstName", nil)
    customer.last_name = custResponse.fetch("lastName", nil)
    customer.company = custResponse.fetch("company", nil)
    customer.email = custResponse.fetch("email", nil)
    customer.phone_number = custResponse.fetch("phoneNumber", nil)
    
    sub.customer = customer;
    
    sub.customer_url = response.fetch("customerUrl", nil)
    sub.product_name = response.fetch("productName", nil)
    sub.tags = response.fetch("tags", nil)
    sub.quantity = response.fetch("quantity", nil)
    next_period_date = response.fetch("nextPeriodDate", nil)
    if not next_period_date.nil?
      sub.next_period_date = Date.parse(next_period_date)
    end
    end_date = response.fetch("end", nil)
    if not end_date.nil?
      sub.end_date = Date.parse(end_date)
    end
          
    sub
  end
end

class FsprgSubscription
  attr_accessor :status, :status_changed, :status_reason, :cancelable, :reference, :test
  attr_accessor :customer, :customer_url, :product_name, :tags, :quantity, :next_period_date, :end_date
end

class FsprgSubscriptionUpdate
  attr_accessor :reference, :product_path, :quantity, :tags, :coupon, :no_end_date, :proration
  
  def initialize(subscription_ref)
    @reference = subscription_ref
  end
  
  def to_xml
    xml = Builder::XmlMarkup.new
    xml.instruct!
    
    xml.subscription {
    
      unless product_path.nil? || product_path.empty?
        xml.productPath(product_path)
      end
      unless quantity.nil? || quantity.empty?
        xml.quantity(quantity)
      end
      unless tags.nil? || tags.empty?
        xml.tags(tags)
      end
      if not no_end_date.nil? and no_end_date
        xml.tag! 'no-end-date', {}
      end
      unless coupon.nil? || coupon.empty?
        xml.coupon(coupon)
      end
      if not proration.nil?
        if proration
          xml.proration('true')
        else
          xml.proration('false')
        end
      end
    }
    
    xml.target!
  end
end

class FsprgCustomer
  attr_accessor :first_name, :last_name, :company, :email, :phone_number
end

class FsprgException < RuntimeError
  def initialize(http_status_code, error_code)
    @http_status_code = http_status_code
    @error_code = error_code
  end
  
  def http_status_code
    @http_status_code
  end
  
  def error_code
    @error_code
  end
end
