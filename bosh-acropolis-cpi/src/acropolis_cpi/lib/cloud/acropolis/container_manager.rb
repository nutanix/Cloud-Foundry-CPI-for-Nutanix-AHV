require 'common/common'
require 'json'

module Bosh
  module AcropolisCloud
    class NutanixContainerManager
      include Helpers

      # Constructor
      # @param [NutanixRestClient] client Client instance
      def initialize(client, logger)
        @client = client
        @logger = logger
      end

      # Fetches a container
      #
      # @param [String] container_uuid
      # @return [RestClient::Response]
      def get_container(container_uuid)
        container = @client.get('v2.0', "storage_containers/#{container_uuid}")
        JSON.parse(container) unless container.nil?
      rescue => e
        raise "Container #{container_uuid} not found."
      end

      # Returns a container's uuid using either
      # the id or the name of the container
      #
      # @param [String] id Container Id
      # @param [String] name Container name
      def get_container_uuid_by_name(name)
        containers = JSON.parse(
          @client.get('v2.0', 'storage_containers')
        )['entities']
        containers.each do |container|
          return container['storage_container_uuid'] if
            container['name'] == name
        end
        raise "Container with name #{name} not found."
      rescue => e
        raise e
      end
    end
  end
end
