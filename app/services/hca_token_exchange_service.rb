# frozen_string_literal: true

class HCATokenExchangeService
  class ExchangeError < StandardError; end
  class UserTokenExpiredError < ExchangeError; end
  class DeniedError < ExchangeError; end

  def initialize(user)
    @user = user
  end

  # Exchange the user's HCA access token for a short-lived,
  # audience-restricted JWT.
  #
  # @param aud [String] target audience URL (e.g. "https://mail.hackclub.com")
  # @param scope [String] delegated scope (e.g. "theseus:send_mail")
  # @return [String] the short-lived JWT
  def exchange_for(aud:, scope:)
    unless @user.hca_access_token.present?
      raise ExchangeError, "User #{@user.id} has no HCA access token"
    end

    response = HTTP
      .basic_auth(user: client_id, pass: client_secret)
      .headers(accept: "application/json")
      .post(exchange_url, form: {
        user_token: @user.hca_access_token,
        aud: aud,
        scope: scope
      })

    body = JSON.parse(response.body.to_s)

    case response.status.to_i
    when 200
      body["access_token"]
    when 401
      if body["error"] == "invalid_user_token"
        raise UserTokenExpiredError, "User's HCA token is invalid or expired"
      else
        raise DeniedError, "Authentication failed: #{body['error']}"
      end
    when 403
      raise DeniedError, "Exchange denied: #{body['error']}"
    else
      raise ExchangeError, "Token exchange failed (HTTP #{response.status}): #{body['error']}"
    end
  rescue HTTP::Error => e
    raise ExchangeError, "Network error during token exchange: #{e.message}"
  rescue JSON::ParserError => e
    raise ExchangeError, "Invalid response from HCA: #{e.message}"
  end

  private

  def exchange_url
    "#{HCAService.host}/api/v1/token/exchange"
  end

  def client_id = ENV.fetch("HCA_CLIENT_ID")
  def client_secret = ENV.fetch("HCA_CLIENT_SECRET")
end
