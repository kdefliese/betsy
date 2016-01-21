class OrdersController < ApplicationController
  #look up callbacks
  #also, in order to make filter work, buttons to do stuff to orders need to send an id into params. (see guest_authorize method, which uses id)
  #this is to help make it so only the person who started an order can do stuff to it.
  before_action :guest_authorize, :only =>[:clear_cart, :cancel_as_guest, :pay]
  before_action :navbar_categories, only: [:cart]


  #the order from the perspective of the merchant
  def show
    @order = Order.find(params[:id])
  end

  #the order from the perspective of the guest
  #stuff needed to view the cart page
  def cart
    if !session[:order_id]
      @cart_status = "empty"
    end
  end

  #before you pay, clearing cart destroys order and orderitems.
  #after you've paid, you instead cancel the order, and the order sticks around in the database
  def clear_cart
    @order = Order.find(session[:order_id])
    @order.destroy!
    session[:order_id] = nil
    redirect_to root_path
  end

  def checkout
    @order = Order.find(session[:order_id])
  end

  def confirm
    @order = Order.find(session[:order_id])

    # Handling box size logic
    user_orderitems = {}
    @order.orderitems.each do |oi|
      if user_orderitems[oi.product.user.username].nil?
        user_orderitems[oi.product.user.username] = [oi]
      else
        user_orderitems[oi.product.user.username] = user_orderitems[oi.product.user.username].push(oi)
      end
    end
    boxes = []
    user_orderitems.each do |store, order_items|
      length = 0
      width = 0
      height = 0
      weight = 0
      order_items.each do |oi|
        length += oi.product.length * oi.quantity
        weight += oi.product.weight * oi.quantity
        height += oi.product.height * oi.quantity
        width += oi.product.width * oi.quantity
      end
      hash = {length: length, width: width, height: height}
      max = hash.key(hash.values.max)
      # NEED TO HANDLE CASE WHERE MULTIPLE BOXES ARE NEEDED

      if hash[max] <= 91.4
        if hash[max] <= 7.6
          box = {length: 7.6, width: 7.6, height: 7.6}
        elsif hash[max] <= 17.8
          box = {length: 17.8, width: 17.8, height: 17.8}
        elsif hash[max] <= 35.6
          box = {length: 35.6, width: 35.6, height: 35.6}
        elsif hash[max] <= 71.1
          box = {length: 71.1, width: 71.1, height: 71.1}
        elsif hash[max] <= 91.4
          box = {length: 91.4, width: 91.4, height: 91.4}
        end
        boxes.push({weight: weight, size: box})
      else
        options = [7.6, 17.8, 35.6, 71.1, 91.4]
        hash[max] -= 91.4
        box = {length: 91.4, width: 91.4, height: 91.4}
        boxes.push({weight: weight, size: box})
        temp_box = []

        while hash[max] >= 0

          options.each do |option|
            if hash[max] > 91.4
              hash[max] -= 91.4
              box = {length: 91.4, width: 91.4, height: 91.4}
              temp_box.push(box)
            elsif hash[max] <= option
              hash[max] -= option
              box = {length: option, width: option, height: option}
              temp_box.push(box)
            end
          end
          weight_each = weight/temp_box.length
          temp_box.each do |t_box|
            boxes.push({ weight: weight_each, size: t_box})
          end
        end

      end

    end
    binding.pry
  end

  def cancel_as_guest
    @order = Order.find(session[:order_id])
    @order.update_attribute(:status, "cancelled")
    session[:order_id] = nil
    @cart_status = "empty"
    redirect_to root_path
  end

  def finalize
    @order = Order.find(session[:order_id])
    @order.decrement_products_stock
    session[:order_id] = nil
    @cart_status = "empty"
    flash[:notice] = "Thank you for your order!"
    redirect_to root_path
  end

  def pay
    @order = Order.find(session[:order_id])
    @order.update(order_params[:order])
    @order.placed_at = Time.now
    @order.status =  "paid"
    @order.save!
    redirect_to order_confirm_path(@order.id)
  end


  #edit and update... are for the guest to do on the cart page?
  #needs more thought
  #we have lots of specific ways we are updating, as it stands right now
  def edit
    @order = Order.find(params[:id])
  end

  def update
    id = params[:id]
    order = Order.find(id)
    order.update_attributes(order_params[:order])
    redirect_to order_path(params[:id])
  end

  private

  def order_params
    params.permit(order:[:status, :cc_name, :email_address, :mailing_address, :cc_number, :cc_exp, :cc_cvv, :zip, :placed_at])
  end

  #views will need to make sure they send in an id to use here
  def guest_authorize
    unless session[:order_id]
    redirect_to root_path
    end
  end

end
