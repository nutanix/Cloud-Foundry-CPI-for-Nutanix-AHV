require 'common/common'
require 'json'

module Bosh
  module AcropolisCloud
    class NutanixVirtualMachineManager
      include Helpers

      # Constructor
      # @param [NutanixRestClient] client Client instance
      def initialize(client, logger)
        @client = client
        @logger = logger
      end

      # Creates a Virtual Machine
      #
      # @param [Hash] config_spec Configuration for creating a new VM
      # @return [String] Uuid of the new VM
      def create_virtual_machine(config_spec)
        task = JSON.parse(@client.post('v2.0', 'vms', config_spec.to_json))
        task_uuid = task['task_uuid']
        TaskManager.wait_on_task(task_uuid, @client, @logger)
      rescue => e
        raise Bosh::Clouds::VMCreationFailed.new(false), e.message
      end

      # Deletes a Virtual Machine
      #
      # @param [String] vm_uuid Uuid of the VM to be deleted
      def delete_virtual_machine(vm_uuid)
        task = JSON.parse(@client.delete('v2.0', "vms/#{vm_uuid}"))
        task_uuid = task['task_uuid']
        TaskManager.wait_on_task(task_uuid, @client, @logger)
      rescue => e
        raise e
      end

      # Turns on the power of a Virtual Machine
      #
      # @param [String] vm_uuid Uuid of the Vm to be rebooted
      # @param [String] power_state "on", "off", "acpi_reboot"
      def set_power_state(vm_uuid, power_state)
        task = JSON.parse(
          @client.post('v2.0', "vms/#{vm_uuid}/set_power_state",
                       { transition: power_state }.to_json)
        )
        TaskManager.wait_on_task(task['task_uuid'], @client, @logger)
      rescue => e
        raise e
      end

      # Fetches details of a Virtual Machine
      #
      # @param [String] vm_uuid Uuid of the Vm to be rebooted
      def get_virtual_machine(vm_uuid, include_disk_config = false,
                              include_nic_config = false)
        query_parameters = { include_vm_disk_config: include_disk_config,
                             include_vm_nic_config: include_nic_config }
        vm = @client.get('v2.0', "vms/#{vm_uuid}", query_parameters)
        JSON.parse(vm) unless vm.nil?
      rescue => e
        message = "VM with id #{vm_uuid} not found."
        raise Bosh::Clouds::VMNotFound.new(false), message
      end

      def load_iso(vm_uuid, vm_disk_id)
        spec = { updateSpec: { isEmpty: false,
                               vmDiskClone: { vmDiskUuid: vm_disk_id } } }
        task = JSON.parse(
          @client.put('v0.8', "vms/#{vm_uuid}/disks/ide-0", spec.to_json)
        )
        task_uuid = task['taskUuid']
        TaskManager.wait_on_task(task_uuid, @client, @logger)
      rescue => e
        raise e
      end

      # Updates the description field of a VM
      #
      # @param [String] vm_uuid
      # @param [String] description
      def update_vm_description(vm_uuid, description)
        task = JSON.parse(@client.put("v2.0", "vms/#{vm_uuid}",
                                      { description: description }.to_json))
        TaskManager.wait_on_task(task['task_uuid'], @client, @logger)
      rescue => e
        raise e.message
      end
    end
  end
end
