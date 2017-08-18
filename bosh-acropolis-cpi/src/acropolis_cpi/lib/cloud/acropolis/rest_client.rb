require 'json'
require 'rest-client'

module Bosh
  module AcropolisCloud
    class NutanixRestClient
      def initialize(endpoint, username, password, logger, timeout = 600)
        @endpoint = endpoint
        @username = username
        @password = password
        @logger = logger
        @http_opt = { headers: { content_type: 'json', accept: 'json' },
                      timeout: timeout, verify_ssl: false,
                      user: @username, password: @password }
      end

      # Makes a GET call
      #
      # @param [String] api_version Version of Nutanix REST Api
      # @param [String] resource The REST resource with its path parameters
      # @param [Hash] query_parameters Query parameters as a Hash where the key
      # @return [RestClient::Response]
      def get(api_version, resource, query_parameters = nil, headers = nil)
        make_rest_call(:get, uri_builder(api_version, resource,
                                         query_parameters), headers)
      end

      # Makes a POST call
      #
      # @param [String] api_version Version of Nutanix REST Api
      # @param [String] resource The REST resource with its path parameters
      # @param [Hash] payload Body of the request
      # @param [Hash] query_parameters Query parameters as a Hash where the key
      # @return [RestClient::Response]
      def post(api_version, resource, payload, query_parameters = nil,
               headers = nil)
        make_rest_call(:post, uri_builder(api_version, resource,
                                          query_parameters), payload, headers)
      end

      # Makes a PUT call
      #
      # @param [String] api_version Version of Nutanix REST Api
      # @param [String] resource The REST resource with its path parameters
      # @param [Hash] payload Body of the request
      # @param [Hash] query_parameters Query parameters as a Hash where the key
      # @return [RestClient::Response]
      def put(api_version, resource, payload, query_parameters = nil,
              headers = nil)
        make_rest_call(:put, uri_builder(api_version, resource,
                                         query_parameters), payload, headers)
      end

      # Makes a GET call
      #
      # @param [String] api_version Version of Nutanix REST Api
      # @param [String] resource The REST resource with its path parameters
      # @param [Hash] query_parameters Query parameters as a Hash where the key
      # @return [RestClient::Response]
      def delete(api_version, resource, query_parameters = nil, headers = nil)
        make_rest_call(:delete, uri_builder(api_version, resource,
                                            query_parameters), headers)
      end

      # Generic method to make a REST call
      #
      # @param [Symbol] method Methods are :get, :post, :put, :delete, :patch
      # @param [String] url
      # @param [Hash] payload
      # @return [String] Returns the result of REST call
      def make_rest_call(method, url, payload = nil, headers = nil)
        options = call_options_builder(method, url, payload, headers)
        RestClient::Request.execute(options)
      rescue => e
        raise e
      end

      # Build options required for making a REST call
      #
      # @param [Symbol] method Methods are :get, :post, :put, :delete, :patch
      # @param [String] url
      # @param [Hash] payload
      # @return [Hash] Returns compiled options
      def call_options_builder(method, url, payload = nil, headers = nil)
        @http_opt[:headers].update(headers) unless headers.nil?
        options = { method: method, url: url }.merge(@http_opt)
        options[:payload] = payload unless payload.nil?
        options
      end

      # Build a URI based on the input parameters passed
      #
      # @param [String] api_version Version of the Nutanix REST Api
      # @param [String] resource The REST resource with its path parameters
      # @param [Hash] query_parameters Query parameters as a Hash where the key
      # fields must be a symbol, i.e. { param1: value1, param2: value2 }
      # @return [String] URI compiled using the inputs passed
      def uri_builder(api_version, resource, query_parameters = nil)
        uri = "#{@endpoint}/#{api_version}/#{resource}"
        unless query_parameters.nil?
          query = '?'
          query_parameters.each { |k, v| query += "#{k}=#{v}&" }
          uri += query[0..-2]
        end
        uri
      end
    end
  end
end
