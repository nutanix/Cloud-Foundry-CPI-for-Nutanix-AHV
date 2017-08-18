require 'common/common'
require 'json'

module Bosh
  module AcropolisCloud
    class Cloud < Bosh::Cloud
      include Helpers

      attr_accessor :logger

      # Constructor :Creates a new BOSH Acropolis CPI instance
      # @param [Hash] options
      def initialize(options)
        @logger = Bosh::Clouds::Config.logger
        @options = options
        validate_options
        @logger.debug("Options: #{options}")
        @client = NutanixRestClient.new(options['endpoint'], options['user'],
                                        options['password'], @logger)
        @vm_manager = NutanixVirtualMachineManager.new(@client, @logger)
        @image_manager = NutanixImageManager.new(@client, @logger)
        @vol_group_manager = NutanixVolumeGroupManager.new(@client, @logger)
        @container_manager = NutanixContainerManager.new(@client, @logger)
        @container_uuid = @container_manager
                          .get_container_uuid_by_name(options['container_name'])
      rescue => e
        cloud_error(e.message)
      end

      # Creates and uploads a new image using stemcell image
      # @param [String] image_path to image file
      # @param [Hash] cloud_properties Cloud properties
      def create_stemcell(image_path, cloud_properties)
        with_thread_name("create_stemcell(#{image_path})") do
          begin
            @logger.debug("Image Path: #{image_path}")
            @logger.debug("Cloud properties: #{cloud_properties}")
            Dir.mktmpdir do |tmp_dir|
              image_name = "#{cloud_properties['name']}/" \
                           "#{cloud_properties['version']}"
              @logger.debug("Image name: #{image_name}")
              image_location = unpack_image(tmp_dir, image_path)
              stemcell_id = @image_manager.create_image(image_name,
                                                        'DISK_IMAGE',
                                                        @container_uuid,
                                                        image_location)
              @logger.debug("Stemcell ID is #{stemcell_id}")
              stemcell_id
            end
          rescue => e
            @logger.error(e)
            cloud_error(e.message)
          end
        end
      end

      # Deletes a stemcell
      # @param [String] stemcell_id
      def delete_stemcell(stemcell_id)
        with_thread_name("delete_stemcell(#{stemcell_id})") do
          begin
            @logger.debug("Stemcell ID is #{stemcell_id}")
            @image_manager.delete_image(stemcell_id)
          rescue => e
            @logger.error(e)
            cloud_error(e.message)
          end
        end
      end

      # Creates a new virtual machine
      # @param [String] agent_id
      # @param [String] stemcell_id
      # @param [Hash] resource_pool
      # @param [Hash] network_spec
      # @param [Hash] existing_disk
      # @param [Hash] environment
      def create_vm(agent_id, stemcell_id, resource_pool, network_spec = nil,
                    existing_disk = nil, environment = nil)
        with_thread_name("create_vm(#{agent_id}") do
          begin
            validate_vm_resource_pool(resource_pool)
            # Check whether ephemeral disk is specified
            ephemeral_disk = (!resource_pool['disk'].nil? &&
                              resource_pool['disk'].to_i > 0)
            # Create agent settings for the VM
            agent_env = initial_agent_settings(agent_id, agent_id, network_spec,
                                               ephemeral_disk, [],
                                               environment, @options['blobstore'],
                                               @options['agent']['mbus'])
            iso_uuid = create_and_upload_env_iso(agent_id, agent_env)
            # Get the disk id of the newly created image.
            iso_disk_id = @image_manager.get_image(iso_uuid)['vm_disk_id']
            # Get disk id of the uploaded stemcell image
            stemcell_disk_id = @image_manager
                               .get_image(stemcell_id)['vm_disk_id']
            network = create_vm_nic_config(network_spec)
            ephemeral_disk_size = ephemeral_disk ? resource_pool['disk'] : nil
            vm_create_specs = create_vm_specs(agent_id, resource_pool['cpu'],
                                              resource_pool['ram'], agent_env,
                                              iso_disk_id, stemcell_disk_id,
                                              network, ephemeral_disk_size)
            @logger.debug("VM Specs: #{vm_create_specs}")
            @vm_manager.create_virtual_machine(vm_create_specs)
            @logger.info("Virtual machine [#{agent_id}] created.")
            unless existing_disk.nil?
              existing_disk.each do |disk_id|
                attach_disk(agent_id, disk_id)
              end
            end
            @vm_manager.set_power_state(agent_id, 'on')
            @logger.info('Virtual machine powered on.')
            # Delete the uploaded iso as it is not required
            @image_manager.delete_image(iso_uuid)
            @logger.info('Deleted the uploaded ENV ISO.')
            agent_id
          rescue => e
            delete_vm(agent_id) if has_vm?(agent_id)
            cloud_error(e.message)
          end
        end
      end

      # Sets VM metadata
      # Since we do not have any field to store metadata
      # for a Nutanix VM, the implemntation is left blank.
      def set_vm_metadata(vm_id, metadata)
        @logger.info('Setting virtual machine metadata...')
      end

      # Deletes a virtual machine
      # @param [String] vm_id
      def delete_vm(vm_id)
        with_thread_name("delete_vm(#{vm_id}") do
          begin
            # Skip if the VM does not exist
            return unless has_vm?(vm_id)
            vm = @vm_manager.get_virtual_machine(vm_id, true, true)
            unless vm['power_state'] == 'off'
              @logger.info('Switching off the VM...')
              @vm_manager.set_power_state(vm_id, 'off')
            end
            @logger.info('Detaching persistent disks attached to VM.')
            vm['vm_disk_info'].each do |disk|
              # If a volume is attached to the virtual machine
              # then detach it before deleting the virtual machine
              vol_group_uuid = disk['disk_address']['volume_group_uuid']
              unless vol_group_uuid.nil?
                @vol_group_manager.detach_from_vm(vol_group_uuid, vm_id)
                @logger.info("Detached volume group #{vol_group_uuid}.")
              end
            end
            @vm_manager.delete_virtual_machine(vm_id)
            @logger.info('Deleted the virtual machine.')
          rescue => e
            @logger.error(e)
            cloud_error(e.message)
          end
        end
      end

      # Check whether virtual machine exists
      def has_vm?(vm_id)
        with_thread_name("has_vm?(#{vm_id})") do
          begin
            @logger.info("Checking if VM with id = #{vm_id} exists...")
            vm = @vm_manager.get_virtual_machine(vm_id)
            !vm.nil? ? true : false
          rescue => e
            @logger.error(e)
            false
          end
        end
      end

      # Reboots a virtual machine
      # @param [String] vm_id
      def reboot_vm(vm_id)
        with_thread_name("reboot_vm(#{vm_id})") do
          begin
            vm = @vm_manager.get_virtual_machine(vm_id)
            if vm['power_state'] == 'off'
              @logger.info("Powering on VM #{vm_id}...")
              @vm_manager.set_power_state(vm_id, 'on')
            else
              @logger.info("Rebooting VM #{vm_id}...")
              @vm_manager.set_power_state(vm_id, 'acpi_reboot')
            end
          rescue => e
            @logger.error(e)
            cloud_error(e.message)
          end
        end
      end

      # Returns a list of disks currently attached to a virtual machine
      # @param [String] vm_id
      def get_disks(vm_id)
        with_thread_name("get_disks(#{vm_id})") do
          begin
            @logger.debug("Requesting disks attached to VM #{vm_id}...")
            vm = @vm_manager.get_virtual_machine(vm_id, true)
            disks = []
            vm['vm_disk_info'].each do |disk|
              unless disk['disk_address']['volume_group_uuid'].nil?
                disks << disk['disk_address']['volume_group_uuid']
              end
            end
            @logger.debug("VM Disks: #{disks}")
            disks
          rescue => e
            @logger.error(e)
            cloud_error(e.message)
          end
        end
      end

      # Creates a new volume group with a volume disk
      # @param [Number] size Size in mega bytes
      # @param [Hash] cloud_properties
      # @param [String] vm_id
      def create_disk(size, cloud_properties, vm_id = nil)
        with_thread_name("create_disk(#{size})") do
          begin
            @logger.debug("Persistent Disk Size: #{size}")
            @logger.debug("Cloud Properties: #{cloud_properties}")
            @logger.debug("VM Id: #{vm_id}")
            # Form a name for the volume group
            vol_group_name = "bosh-peristent-disk-#{vm_id}-#{rand(1000)}"
            # Create the volume group
            volume_uuid = @vol_group_manager.create_volume_group(vol_group_name)
            @logger.info("New volume group created [#{vol_group_name}]")
            # Create a volume disk
            @vol_group_manager.create_volume_disk(volume_uuid, size,
                                                  @container_uuid)
            @logger.info("New volume disk created on volume #{vol_group_name}.")
            # Return volume group's uuid
            volume_uuid
          rescue => e
            logger.error(e)
            cloud_error(e.message)
          end
        end
      end

      # Check whether volume group exists
      # disk_id here maps to the uuid of
      # a volume group in Nutanix
      # @param [String] disk_id
      def has_disk?(disk_id)
        with_thread_name("has_disk?(#{disk_id})") do
          begin
            @logger.info("Checking if volume group with id=#{disk_id} exists")
            # Fetch the volume group
            vol_group = @vol_group_manager.get_volume_group(disk_id)
            # If vol_group is not nil return true, false otherwise
            !vol_group.nil? ? true : false
          rescue => e
            @logger.error(e)
            false
          end
        end
      end

      # Deletes a volume group
      # @param [String] disk_id
      def delete_disk(disk_id)
        with_thread_name("delete_disk(#{disk_id})") do
          begin
            # Skip if disk does not exist
            return unless has_disk?(disk_id)
            @logger.debug("Deleting volume group #{disk_id}...")
            @vol_group_manager.delete_volume_group(disk_id)
            @logger.debug("Deleted volume group #{disk_id}.")
          rescue => e
            logger.error(e)
            cloud_error(e.message)
          end
        end
      end

      # Attaches volume group to a virtual machine
      # @param [String] vm_id
      # @param [String] disk_id
      def attach_disk(vm_id, disk_id)
        with_thread_name("attach_disk(#{vm_id}, #{disk_id})") do
          begin
            # Don't go further if the volume group is already attached
            return if volume_group_attached?(vm_id, disk_id)
            @logger.debug("Attaching volume group #{disk_id} to VM #{vm_id}")
            @vol_group_manager.attach_to_vm(disk_id, vm_id)
            update_agent_settings(vm_id) do |settings|
              settings['disks']['persistent'] ||= {}
              disks = settings['disks']
              drive = "/dev/sd#{get_drive_letter(disks)}"
              settings['disks']['persistent'][disk_id] = drive
            end
          rescue => e
            @logger.error(e)
            cloud_error(e.message)
          end
        end
      end

      # Detaches volume group from a virtual machine
      # @param [String] vm_id
      # @param [String] disk_id
      def detach_disk(vm_id, disk_id)
        with_thread_name("detach_disk(#{vm_id}, #{disk_id})") do
          begin
            return unless volume_group_attached?(vm_id, disk_id)
            @logger.debug("Detaching volume group #{disk_id} to VM #{vm_id}")
            @vol_group_manager.detach_from_vm(disk_id, vm_id)
            update_agent_settings(vm_id) do |settings|
              settings['disks']['persistent'] ||= {}
              settings['disks']['persistent'].delete(disk_id)
            end
          rescue => e
            @logger.error(e)
            cloud_error(e.message)
          end
        end
      end

      # Not implemented as AHV does not support
      # disk snapshots currently.
      def snapshot_disk(disk_id, metadata)
        raise Bosh::Clouds::NotSupported.new(false),
              'snapshot_disk is not supported.'
      end

      # Not implemented as AHV does not support
      # disk snapshots currently.
      def delete_snapshot(snapshot_id)
        raise Bosh::Clouds::NotSupported.new(false),
              'delete_snapshot is not supported.'
      end

      # Not implemented as AHV handles network configuration.
      def configure_networks(vm_id, network_spec)
        raise Bosh::Clouds::NotSupported.new(false),
              'configure_networks is not supported.'
      end

      # Following methods are not a part of the Cloud Provider Interface.
      # These are helper methods written to make things convenient for us.

      # Validates constructor's parameters
      def validate_options
        required_keys = %w(endpoint user password
                           container_name agent ntp blobstore)
        missing_keys = []
        required_keys.each do |key|
          unless @options.has_key?(key)
            missing_keys << key
          end
        end
        message = "Missing configuration parameters: #{missing_keys}"
        raise ArgumentError, message unless missing_keys.empty?
      end

      # Validates create_vm method's resource pool
      # @param [Hash] pool
      def validate_vm_resource_pool(pool)
        required_keys = %w(cpu ram)
        missing_keys = []
        required_keys.each do |key|
          unless pool.has_key?(key)
            missing_keys << key
          end
        end
        message = "Missing resource pool parameters: #{missing_keys}"
        raise ArgumentError, message unless missing_keys.empty?
        unless pool['ram'].to_i > 0
          raise "The value #{pool['ram']} for ram is invalid."
        end
        unless pool['cpu'].to_i > 0
          raise "The value #{pool['cpu']} for cpu is invalid."
        end
      end

      # Creates an ISO with agent settings and uploads it
      # @param [String] vm_id
      # @param [Hash] settings Agent settings
      def create_and_upload_env_iso(vm_id, settings)
        Dir.mktmpdir do |tmp|
          # Generate ISO and get its path
          iso_path = generate_env_iso(tmp, settings)
          cloud_error('Error while creating iso...') if iso_path.nil?
          image_name = "iso-image-#{vm_id}"
          # Upload the ISO ang get the iso_uuid
          iso_uuid = @image_manager.create_image(image_name, 'ISO_IMAGE',
                                                 @container_uuid, iso_path)
          iso_uuid
        end
      rescue => e
        raise e
      end

      # Gathers network config information and returns a list
      # of network configurations for a virtual machine.
      # @return [Array]
      def create_vm_nic_config(network_spec)
        @logger.debug("Network spec: #{network_spec}")
        vm_nic_config = []
        # Get available networks
        networks = JSON.parse(@client.get('v2.0', 'networks'))['entities']
        # Iterate through network spec in the config and create network
        # config. spec. for the virtual machine
        network_spec.each do |name, net|
          network ||= {}
          cloud_error("[#{name}] Must provide cloud properties.") if
            net['cloud_properties'].nil?
          # Fetch subnet name from config
          subnet = net['cloud_properties']['subnet']
          cloud_error("[#{name}] Must provide subnet name.") if subnet.nil?
          # Fetch network's uuid from subnet name
          network = networks.find { |n| n['name'] == subnet }
          cloud_error("[#{name}] Subnet #{subnet} not found") if network.nil?
          network_uuid = network['uuid']
          # When static IP is configured
          if net['type'] == 'manual'
            ip = net['ip']
            cloud_error("[#{name}:manual] Must provide IP Address.") if ip.nil?
            network[:request_ip] = true
            network[:requested_ip_address] = ip
          end
          network[:network_uuid] = network_uuid
          # Add this network spec to the list
          vm_nic_config << network
        end
        vm_nic_config
      rescue => e
        raise e
      end

      # Creates the payload for creating a virtual machine
      # @param [String] vm_id
      # @param [Number] cpu
      # @param [Number] ram
      # @param [String] description
      # @param [String] cd_rom_disk
      # @param [String] system_disk
      # @param [Hash] network
      # @param [Number] ephemeral_disk_size
      # @return [Hash]
      def create_vm_specs(vm_id, cpu, ram, description, cd_rom_disk,
                          system_disk, network, ephemeral_disk_size = nil)
        vm_create_specs = {
          name: "bosh-#{vm_id}", uuid: vm_id, memory_mb: ram, num_vcpus: cpu,
          description: "DO NOT DELETE #{description.to_json}",
          vm_disks: [ # CD-ROM
            { is_cdrom: true, is_empty: false,
              disk_address: { device_bus: 'ide' },
              vm_disk_clone: { disk_address: { vmdisk_uuid: cd_rom_disk } } },
            # System/Boot Disk
            { is_cdrom: false, is_empty: false,
              disk_address: { device_bus: 'scsi' },
              vm_disk_clone: { disk_address: { vmdisk_uuid: system_disk } } }
          ],
          vm_nics: []
        }
        unless ephemeral_disk_size.nil?
          vm_create_specs[:vm_disks] << {
            is_cdrom: false, is_empty: false,
            disk_address: { device_bus: 'scsi' },
            vm_disk_create: {
              storage_container_uuid: @container_uuid,
              size: (ephemeral_disk_size / 1000) * (1024 * 1024 * 1024)
            }
          }
        end
        network.each { |n| vm_create_specs[:vm_nics] << n }
        vm_create_specs
      end

      # Reads agent settings
      # @return [Hash]
      def read_agent_settings(vm_id)
        vm = @vm_manager.get_virtual_machine(vm_id)
        description = vm['description']
        JSON.parse(description[14..-1])
      rescue => e
        raise e
      end

      # Updates agent settings
      # @param [String] vm_id
      # @param [Hash] settings
      def update_settings(vm_id, settings)
        @logger.debug("Updated settings :#{settings}")
        iso_uuid = create_and_upload_env_iso(vm_id, settings)
        iso_disk_id = @image_manager.get_image(iso_uuid)['vm_disk_id']
        @vm_manager.load_iso(vm_id, iso_disk_id)
        description = "DO NOT DELETE #{settings.to_json}"
        @vm_manager.update_vm_description(vm_id, description)
        @image_manager.delete_image(iso_uuid)
      rescue => e
        raise e
      end

      # Checks whether a volume group is attached to a VM
      # @param [String] vm_id
      # @param [String] vol_group_uuid
      # @return [Boolean]
      def volume_group_attached?(vm_id, vol_group_uuid)
        vol_group = @vol_group_manager.get_volume_group(vol_group_uuid)
        return false unless vol_group.has_key?('attachment_list')
        vol_group['attachment_list'].each do |vm|
          return true if vm['vm_uuid'] == vm_id
        end
        false
      rescue => e
        raise e
      end

      # Creates agent settings hash
      # @param [String] vm_id
      # @param [String] agent_id
      # @param [Hash] network_spec
      # @param [Boolean] ephemeral_disk
      # @param [Array] existing_disk
      # @param [Hash] environment
      # @param [Hash] blobstore
      # @param [String] mbus
      # @return [Hash]
      def initial_agent_settings(vm_id, agent_id, network_spec, ephemeral_disk,
                       existing_disk, environment, blobstore, mbus)
        disk_letters = ('a'..'z').to_a
        config = { vm: { name: vm_id }, agent_id: agent_id,
                   environment: environment, blobstore: blobstore,
                   mbus: mbus, networks: network_spec,
                   disks: { system: "/dev/sd#{disk_letters.shift}",
                            persistent: {} } }
        if ephemeral_disk
          config[:disks][:ephemeral] = "/dev/sd#{disk_letters.shift}"
        end
        config
      end

      def get_drive_letter(disks)
        letters = ('a'..'z').to_a
        used ||= []
        used << disks['system'][-1] unless disks['system'].nil?
        used << disks['ephemeral'][-1] unless disks['ephemeral'].nil?
        disks['persistent'].each { |_, path| used << path[-1] }
        available = letters - used
        available.empty? ? nil : available[0]
      end

      def update_agent_settings(vm_id)
        raise ArgumentError, 'Block is not provided' unless block_given?
        settings = read_agent_settings(vm_id)
        yield settings
        update_settings(vm_id, settings)
      rescue => e
        raise e
      end
    end # End of class
  end
end
