# frozen_string_literal: true

class TheseusMailService
  class MailError < StandardError; end

  THESEUS_URL = ENV.fetch("THESEUS_URL", "https://mail.hackclub.com")

  def initialize(user)
    @user = user
  end

  # Send mail to the user via Theseus using the delegated auth flow.
  # The user's address is fetched by Theseus from HCA — Hackatime never sees it.
  #
  # @param item [String] what to send (e.g. "sticker", "postcard")
  # @return [Hash] response from Theseus
  def send_mail(item:)
    jwt = HcaTokenExchangeService.new(@user).exchange_for(
      aud: "https://mail.hackclub.com",
      scope: "theseus:send_mail"
    )

    response = HTTP
      .auth("Bearer #{jwt}")
      .headers(accept: "application/json")
      .post("#{THESEUS_URL}/api/v1/delegated/send_mail", json: { item: item })

    body = JSON.parse(response.body.to_s)

    case response.status.to_i
    when 200, 201, 202
      body
    when 401
      raise MailError, "Theseus rejected the JWT: #{body['message'] || body['error']}"
    when 422
      raise MailError, "Theseus could not process: #{body['message'] || body['error']}"
    else
      raise MailError, "Theseus returned HTTP #{response.status}: #{body['message'] || body['error']}"
    end
  rescue HTTP::Error => e
    raise MailError, "Network error calling Theseus: #{e.message}"
  rescue JSON::ParserError => e
    raise MailError, "Invalid response from Theseus: #{e.message}"
  end
end
