class ClientsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client, only: [:update, :destroy]

  def create
    @client = current_user.clients.build(client_params)

    if @client.save
      render json: { success: true, client: client_json(@client) }
    else
      render json: { success: false, errors: @client.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @client.update(client_params)
      render json: { success: true, client: client_json(@client) }
    else
      render json: { success: false, errors: @client.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @client.logs.update_all(client_id: nil)
    @client.destroy
    render json: { success: true }
  end

  def search
    term = params[:q].to_s.strip
    clients = current_user.clients.search(term).ordered.limit(10)
    render json: clients.map { |c| client_json(c) }
  end

  private

  def set_client
    @client = current_user.clients.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:name, :email, :phone, :address, :tax_id, :notes)
  end

  def client_json(client)
    {
      id: client.id,
      name: client.name,
      email: client.email,
      phone: client.phone,
      address: client.address,
      tax_id: client.tax_id,
      notes: client.notes,
      invoices_count: client.invoices_count,
      initials: client.display_initials,
      last_invoice_date: client.last_invoice_date&.strftime("%b %d, %Y")
    }
  end
end
