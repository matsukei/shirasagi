class Inquiry::Agents::Nodes::FormController < ApplicationController
  include Cms::NodeFilter::View
  include SimpleCaptcha::ControllerHelpers

  before_action :set_columns, only: [:new, :confirm, :create, :sent]
  before_action :set_answer, only: [:new, :confirm, :create]

  private
    def set_columns
      @columns = Inquiry::Column.site(@cur_site).
        where(node_id: @cur_node.id, state: "public").
        order_by(order: 1)
    end

    def set_answer
      @items = []
      @data = {}
      @columns.each do |column|
        @items << [column, params[:item].try(:[], "#{column.id}")]
        @data[column.id] = params[:item].try(:[], "#{column.id}")
      end
      @answer = Inquiry::Answer.new(site_id: @cur_site.id, node_id: @cur_node.id)
      @answer.remote_addr = request.env["HTTP_X_REAL_IP"] || request.remote_ip
      @answer.user_agent = request.user_agent
      @answer.set_data(@data)
    end

  public
    def new
      #
    end

    def confirm
      if !@answer.valid?
        render action: :new
      end
    end

    def create
      if params[:submit].present?
        if @cur_node.captcha_enabled?
          @answer.captcha = params[:answer].try(:[], :captcha)
          @answer.captcha_key = params[:answer].try(:[], :captcha_key)
          unless @answer.valid_with_captcha?
            return render action: :confirm
          end
        end
        @answer.save
        if @cur_node.notify_mail_enabled?
          Inquiry::Mailer.notify_mail(@cur_site, @cur_node, @answer).deliver
        end
        if @cur_node.reply_mail_enabled?
          Inquiry::Mailer.reply_mail(@cur_site, @cur_node, @answer).try(:deliver)
        end
        redirect_to "#{@cur_node.url}sent.html"
      else
        render action: :new
      end
    end

    def sent
      render action: :sent
    end
end
