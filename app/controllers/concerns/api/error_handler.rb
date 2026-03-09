# frozen_string_literal: true

module Api::ErrorHandler
  def self.included(base)
    base.class_eval do
      rescue_from StandardError do |e|
        # Safely.report_exception(e)
        respond_with_error("unexpected_error", e.message, 500)
      end
      rescue_from PupiError do |e|
        # Safely.report_exception(e) if e.critical?
        respond_with_error(e.code, e.context, e.http_status, e.custom_headers)
      end
      rescue_from ActiveRecord::StatementInvalid, ActiveRecord::QueryCanceled do |_e|
        message = I18n.t('activerecord.errors.database_timeout')
        respond_with_error('database_timeout', message, 504)
      end
      rescue_from ActiveRecord::RecordNotFound do |e|
        message = I18n.t('activerecord.errors.item_not_found', item: e.model)
        respond_with_error('record_not_found', message, 404)
      end
      rescue_from ActiveRecord::RecordInvalid do |e|
        respond_with_error("invalid_parameters", { message: e.record.errors.messages, errors: e.record.errors }, 400)
      end
    end
  end

  private

  def respond_with_error(code = "unknown_error", context = {}, http_status = nil, custom_headers = {})
    context = {message: context} if context.is_a?(String)
    context[:code] = code unless context.key?(:code)
    custom_headers.each do |header_name, header_value|
      response.set_header(header_name, header_value)
    end
    render json: context, status: http_status || 500
  end
end
