require 'FastSpring'
require 'digest/md5'

class PagesController < ApplicationController
  before_filter :init_store
  
  def home
    
  end
  
  def billing
    if (subscribed?)
      redirect_to '/pages/subPage1'
    else
      url = @fastspring.create_subscription(@product_ref, @user.id.to_s)
      redirect_to url
    end
  end

  def subPage1
    if params.has_key?(:cancel)
      begin
        @cancelSub = @fastspring.cancel_subscription(@user.subscription.reference)
      rescue FsprgException => fsprgEx
        @cancelEx = fsprgEx
      end
    elsif params.has_key?(:renew)
      begin
        @fastspring.renew_subscription(@user.subscription.reference)
      rescue FsprgException => fsprgEx
        @renewEx = fsprgEx
      end
    elsif params.has_key?(:update)
      update = FsprgSubscriptionUpdate.new(@user.subscription.reference)
      
      if params.has_key?(:productPath)
        update.product_path = params[:productPath]
      end
      if params.has_key?(:tags)
        update.tags = params[:tags]
      end
      if params.has_key?(:quantity)
        update.quantity = params[:quantity]
      end
      if params.has_key?(:coupon)
        update.coupon = params[:coupon]
      end
      if params.has_key?(:noenddate)
        update.no_end_date = true
      end
      if params.has_key?(:proration)
        update.proration = true
      else
        update.proration = false
      end
      
      begin
        @updateSub = @fastspring.update_subscription(update)
      rescue FsprgException => fsprgEx
        @updateEx = fsprgEx
      end
    end
    
    begin
      @getSub = @fastspring.get_subscription(@user.subscription.reference)
    rescue FsprgException => fsprgEx
      @getEx = fsprgEx
    end
  end
  
  def activate
    privatekey = 'my_private_key'
    if Digest::MD5.hexdigest(params[:security_data] + privatekey) == params[:security_hash]
      customer_ref = params[:customerRef]
      subscription_ref = params[:subscriptionRef]
        
      begin
        act_user = User.find(customer_ref)
        
        if act_user.subscription.nil?
          act_user.subscription = Subscription.create(:reference => subscription_ref)
        end
      rescue ActiveRecord::RecordNotFound
        logger.error { "User was not found" }
      end
    end
        
    render :nothing => true, :status => 200, :content_type => 'text/html'
  end
  
  def deactivate
    privatekey = 'my_private_key'
    if Digest::MD5.hexdigest(params[:security_data] + privatekey) == params[:security_hash]
      customer_ref = params[:customerRef]
        
      begin
        act_user = User.find(customer_ref)
        
        act_user.subscription.delete
      rescue ActiveRecord::RecordNotFound
        logger.error { "User was not found" }
      end
    end
        
    render :nothing => true, :status => 200, :content_type => 'text/html'
  end
  
  def subscribed?
    if not @user.subscription.nil?
      begin
        sub = @fastspring.get_subscription(@user.subscription.reference)
                  
        if sub and sub.status == "active"
          return true
        end
      rescue FsprgException => fsprgEx
        logger.error { fsprgEx }
      end
    end

    false
  end
  
  private
    def init_store
      @fastspring = FastSpring.new('your_store_id', 'your_api_username', 'your_api_password', 'your_company_id')
      
      @fastspring.test_mode = true
      
      @product_ref = 'subprd1'
      
      @user = User.find(1)
    end

end
