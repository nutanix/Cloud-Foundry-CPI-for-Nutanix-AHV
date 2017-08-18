require 'common/common'
require 'json'

module Bosh
  module AcropolisCloud
    class NutanixVolumeGroupManager
      include Helpers

      # Constructor
      # @param [NutanixRestClient] client Client instance
      def initialize(client, logger)
        @client = client
        @logger = logger
      end

      # Creates a volume group
      #
      # @param [String] name Name of the volume group
      # @return [String] Uuid of the volume group
      def create_volume_group(name)
        @logger.debug('Request for creating a new' \
                      "volume group with name = #{name}")
        task = JSON.parse(
          @client.post('v2.0', 'volume_groups', { name: name }.to_json)
        )
        task_uuid = task['task_uuid']
        TaskManager.wait_on_task(task_uuid, @client, @logger)
      rescue => e
        raise e
      end

      # Deletes a volume group
      #
      # @param [String] volume_group_uuid
      def delete_volume_group(volume_group_uuid)
        @logger.debug('Request for deleting a volume group' \
                      "with uuid = #{volume_group_uuid}")
        task = JSON.parse(
          @client.delete('v2.0', "volume_groups/#{volume_group_uuid}")
        )
        task_uuid = task['task_uuid']
        TaskManager.wait_on_task(task_uuid, @client, @logger)
      rescue => e
        raise e
      end

      # Fetches an existing volume group
      #
      # @param [String] volume_group_uuid
      # @return [RestClient::Response] Uuid of the volume group
      def get_volume_group(volume_group_uuid, include_disk_size = false)
        query_parameters = { include_disk_size: include_disk_size }
        volume_group = @client.get('v2.0', "volume_groups/#{volume_group_uuid}",
                                   query_parameters)
        JSON.parse(volume_group) unless volume_group.nil?
      rescue => e
        message = "Volume group #{volume_group_uuid} not found."
        raise Bosh::Clouds::DiskNotFound.new(false), message if
          volume_group.nil?
      end

      # Attaches a volume group to a virtual machine
      #
      # @param [String] volume_group_uuid
      # @param [String] vm_uuid
      def attach_to_vm(volume_group_uuid, vm_uuid)
        task = JSON.parse(
          @client.post('v2.0', "volume_groups/#{volume_group_uuid}/attach",
                       { vm_uuid: vm_uuid }.to_json)
        )
        task_uuid = task['task_uuid']
        TaskManager.wait_on_task(task_uuid, @client, @logger)
      rescue => e
        raise Bosh::Clouds::DiskNotAttached.new(false), e.message
      end

      # Detaches a volume group from a virtual machine
      #
      # @param [String] volume_group_uuid
      # @param [String] vm_uuid
      def detach_from_vm(volume_group_uuid, vm_uuid)
        task = JSON.parse(
          @client.post('v2.0', "volume_groups/#{volume_group_uuid}/detach",
                       { vm_uuid: vm_uuid }.to_json)
        )
        task_uuid = task['task_uuid']
        TaskManager.wait_on_task(task_uuid, @client, @logger)
      rescue => e
        raise Bosh::Clouds::DiskNotAttached.new(false), e.message
      end

      # Creates a volume disk
      #
      # @param [String] volume_group_uuid
      # @param []
      def create_volume_disk(volume_group_uuid, size_in_mb,
                             storage_container_uuid)
        spec = { create_config:
                   # Converting GB to Bytes
                   { size: size_in_mb * 1_048_576,
                     storage_container_uuid: storage_container_uuid } }
        task = JSON.parse(
          @client.post('v2.0', "volume_groups/#{volume_group_uuid}/disks",
                       spec.to_json)
        )
        task_uuid = task['task_uuid']
        TaskManager.wait_on_task(task_uuid, @client, @logger)
      rescue => e
        raise e
      end
    end
  end
end
