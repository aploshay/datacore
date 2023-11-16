# frozen_string_literal: true

class SdaController < ApplicationController
  protect_from_forgery with: :null_session

  def show
    if user_signed_in? && current_ability.admin?
      render plain: sda_url_for(params[:collection], "#{params[:object]}.#{params[:format]}"), status: 200
    else
      render plain: 'action unavailable', status: 403
    end
  end

  def test_request
    # 404
    string = "http://localhost:8181/datacore/xxx9352841_home_banner.jpg"
    filename = "not available"
    # 200
    string = "http://localhost:8181/datacore/nv9352841_home_banner.jpg"
    filename = "home_banner.jpg"
    # 503 - but only briefly
    string = "http://localhost:8181/datacore/fq977t78v_quaternary_EastSouthBend_in_100k_readme.txt"
    filename = "readme.txt"
    # 200
    string = "http://localhost:8181/datacore/nv9352841_home_banner.jpg"
    filename = "home_banner.jpg"

    uri = URI.parse(string)
    request = Net::HTTP::Get.new(uri.request_uri)
    user = "datacore"
    pass = "c94c94854864a13605541daeba4f0b55"
    request['Authorization'] = "#{user}:#{pass}"
    result = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http|
      http.request(request)
    }
    case result.code
      when '503'
        render plain: '503'
      when '200'
        #render plain: result.body
        send_data result.body, filename: filename
      when '404'
        render plain: '404'
      else
        render plain: 'unknown result'
    end
  end

  private
    def sda_url_for(collection, object, version: 1)
      Settings.sda_api.show % [collection, object, version]
    end
end
