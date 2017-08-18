require 'spec_helper'
require 'cloud/acropolis/cloud'
require 'kernel'

describe Bosh::AcropolisCloud::Cloud do
  subject(:cloud_obj) { Bosh::AcropolisCloud::Cloud.new(mock_cloud_options['options']) }
  let(:logger) { Bosh::Clouds::Config.logger }
  let(:incorrect_cloud_options) do
    { 'options' => { 'user' => MOCK_ACCESS_USERNAME,
                     'password' => MOCK_ACCESS_PASSWORD,
                     'endpoint' => MOCK_ACCESS_ENDPOINT,
                     'container_name' => 'c_name',
                     'agent' => { 'mbus' => 'https://username:password@10.0.0.1:6868' },
                     'blobstore' => { 'options' => { 'blobstore_path' =>
                                                      '/var/vcap/micro_bosh/data/cache',
                                                      'path' => '/var/vcap/micro_bosh/data/cache' },
                                                      'provider' => 'local' } } }
  end
  let(:f) { instance_double('File like object') }
  let(:disk) { 'disk1' }
  let(:cloud_properties) do
   { 'id' => 'ff869c70-e406-4234-5997-ee4878ca924c',
     'name' => 'cloudname',
     'version' => 'cloudversion',
     'container_name' => 'valid_container_name' }
  end
  let(:network_spec) do
    { 'default' => { 'cloud_properties' => { 'subnet' => 'vmnet' },
      'default' => %w(dns gateway), 'dns' => ['10.5.4.22'],
      'gateway' => '10.5.136.1',
      'ip' => '10.0.0.1',
      'netmask' => '255.255.252.0',
      'type' => 'manual' } }
  end
  let(:vm_create_specs) do
    { name: 'bosh-agent_id', uuid: 'agent_id',
      memory_mb: 16_384, num_vcpus: 4,
      description: get_description(''),
      vm_disks: [{ is_cdrom: true,
                   is_empty: false,
                   disk_address: { device_bus: 'ide' },
                   vm_disk_clone: { disk_address: { vmdisk_uuid: 'iso_disk_id' } } },
                 { is_cdrom: false, is_empty: false,
                   disk_address: { device_bus: 'scsi' },
                   vm_disk_clone: { disk_address: { vmdisk_uuid: 'stemcell_disk_id' } } },
                 { is_cdrom: false, is_empty: false,
                   disk_address: { device_bus: 'scsi' },
                   vm_disk_create: { storage_container_uuid: 'cont_uuid',
                                     size: 21_474_836_480 } }],
      vm_nics: [{ 'uuid' => 'vmnet_uuid', 'name' => 'vmnet', request_ip: true,
                  requested_ip_address: '10.0.0.1', network_uuid: 'vmnet_uuid' }] }
  end
  let(:vm_create_specs_with_existing_disk) do
    { name: 'bosh-agent_id', uuid: 'agent_id',
      memory_mb: 16_384, num_vcpus: 4,
      description: get_description('"existing_disk_id":"/dev/sdc"'),
      vm_disks: [{ is_cdrom: true,
                   is_empty: false,
                   disk_address: { device_bus: 'ide' },
                   vm_disk_clone: { disk_address: { vmdisk_uuid: 'iso_disk_id' } } },
                 { is_cdrom: false, is_empty: false,
                   disk_address: { device_bus: 'scsi' },
                   vm_disk_clone: { disk_address: { vmdisk_uuid: 'stemcell_disk_id' } } },
                 { is_cdrom: false, is_empty: false,
                   disk_address: { device_bus: 'scsi' },
                   vm_disk_create: { storage_container_uuid: 'cont_uuid',
                                     size: 21_474_836_480 } }],
      vm_nics: [{ 'uuid' => 'vmnet_uuid', 'name' => 'vmnet', request_ip: true,
                  requested_ip_address: '10.0.0.1', network_uuid: 'vmnet_uuid' }] }
  end
  let(:agent_conf_ep) { { vm: { name: 'agent_id' }, agent_id: 'agent_id',
                       environment: nil, blobstore: mock_cloud_options['options']['blobstore'],
                       mbus: mock_cloud_options['options']['agent']['mbus'],
                       networks: network_spec,
                       disks: { system: '/dev/sda',
                       persistent: {}, ephemeral: '/dev/sdb' } } }
  let(:vm_description) { { 'vm' => { 'name' => 'agent_id' },
                           'agent_id' => 'agent_id',
                           'environment' => nil,
                           'blobstore' => { 'options' =>
                                            { 'blobstore_path' =>
                                              '/var/vcap/micro_bosh/data/cache',
                                              'path' => '/var/vcap/micro_bosh/data/cache' },
                                            'provider' => 'local' },
                           'mbus' => 'https://username:password@10.0.0.1:6868',
                           'networks' => { 'default' => { 'cloud_properties' => { 'subnet' => 'vmnet' },
                           'default' => %w(dns gateway), 'dns' => ['10.5.4.22'],
                           'gateway' => '10.5.136.1', 'ip' => '10.0.0.1',
                           'netmask' => '255.255.252.0', 'type' => 'manual' } },
                           'disks' => { 'system' => '/dev/sda', 'ephemeral' => '/dev/sdb',
                           'persistent' => {} } } }
  let(:network) { [{  'uuid' => 'vmnet_uuid', 'name' => 'vmnet',
                      request_ip: true,
                      requested_ip_address: '10.0.0.1',
                      network_uuid: 'vmnet_uuid' }] }
  let(:vm_manager) do
    instance_double('Bosh::AcropolisCloud::NutanixVirtualMachineManager')
  end
  let(:container_manager) do
    instance_double('Bosh::AcropolisCloud::NutanixContainerManager')
  end
  let(:client) do
    instance_double('Bosh::AcropolisCloud::NutanixRestClient')
  end
  let(:image_manager) do
    instance_double('Bosh::AcropolisCloud::NutanixImageManager')
  end
  let(:vol_group_manager) do
    instance_double('Bosh::AcropolisCloud::NutanixVolumeGroupManager')
  end

  before do
    allow(Bosh::AcropolisCloud::NutanixVirtualMachineManager)
      .to receive(:new).with(client, logger)
      .and_return(vm_manager)

    allow(Bosh::AcropolisCloud::NutanixContainerManager)
      .to receive(:new).with(client, logger)
      .and_return(container_manager)

    allow(Bosh::AcropolisCloud::NutanixRestClient)
      .to receive(:new).with(MOCK_ACCESS_ENDPOINT, MOCK_ACCESS_USERNAME,
                             MOCK_ACCESS_PASSWORD, logger)
      .and_return(client)

    allow(Bosh::AcropolisCloud::NutanixImageManager)
      .to receive(:new).with(client, logger)
      .and_return(image_manager)

    allow(Bosh::AcropolisCloud::NutanixVolumeGroupManager)
      .to receive(:new).with(client, logger)
      .and_return(vol_group_manager)
  end

  before do
    allow(container_manager).to receive(:get_container_uuid_by_name)
      .with('c_name')
      .and_return('cont_uuid')
  end

  describe '#validate_options' do
    it 'raises error' do
      expect { described_class.new(incorrect_cloud_options) }
        .to raise_error(Bosh::Clouds::CloudError)
    end
  end

  describe '#validate_vm_resource_pool' do
    context 'when one of the parameters of resource pool is missing' do
      it 'raises error ArgumentError' do
        expect { cloud_obj.validate_vm_resource_pool('cpu' => 4, 'disk' => 20_000) }
          .to raise_error(ArgumentError)
      end
    end
    context 'when value for ram is invalid that is not greater than zero' do
      it 'raises error' do
        expect { cloud_obj.validate_vm_resource_pool('cpu' => 4, 'disk' => 1_234, 'ram' => 0) }
          .to raise_error(RuntimeError)
      end
    end
    context 'when value for cpu is invalid that is not greater than zero' do
      it 'raises error' do
        expect { cloud_obj.validate_vm_resource_pool('cpu' => 0, 'disk' => 10, 'ram' => 16_234) }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#create_stemcell' do
    let(:result) { instance_double('Bosh::Exec::Result') }
    before do
      allow(Dir).to receive(:mktmpdir).and_yield('temp_dir')

      allow(Bosh::Exec).to receive(:sh)
        .with('tar -C temp_dir -xzf img_path 2>&1', :on_error => :return)
        .and_return(result)

      allow(result).to receive(:failed?)
        .and_return(false)

      allow(File).to receive(:exist?)
        .with('location')
        .and_return(true)

      allow(File).to receive(:join)
        .with('temp_dir', 'root.img')
        .and_return('location')
    end
    context 'when image creation succeeds' do
      it 'creates a stemcell' do
        allow(image_manager).to receive(:create_image)
          .with('cloudname/cloudversion', 'DISK_IMAGE', 'cont_uuid', 'location')
          .and_return('task_uuid' => 'task_id')

        expect(cloud_obj.create_stemcell('img_path', cloud_properties))
          .to eq('task_uuid' => 'task_id')
      end
    end
    context 'when image creation fails' do
      it 'raises error' do
        allow(image_manager).to receive(:create_image)
          .with('cloudname/cloudversion', 'DISK_IMAGE', 'cont_uuid', 'location')
          .and_raise

        expect { cloud_obj.create_stemcell('img_path', cloud_properties) }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end
  end

  describe '#delete_stemcell' do
    context 'when delete succeeds' do
      it 'deletes a stemcell' do
        allow(image_manager).to receive(:delete_image)
          .with('stemcell_id')

        expect(cloud_obj.delete_stemcell('stemcell_id'))
          .to be nil
      end
    end
    context 'when delete fails' do
      it 'raises error' do
        allow(image_manager).to receive(:delete_image)
          .with('stemcell_id')
          .and_raise

        expect { cloud_obj.delete_stemcell('stemcell_id') }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end
  end

  describe '#delete_vm' do
    before do
      allow(vm_manager).to receive(:get_virtual_machine)
        .with('vm_id', true, true)
        .and_return('vm_disk_info' => [{ 'disk_address' =>
         { 'volume_group_uuid' => 'vg-uuid' } }])

      allow(vm_manager).to receive(:get_virtual_machine)
        .with('vm_id')
        .and_return('vm_disk_info' => [{ 'disk_address' =>
         { 'volume_group_uuid' => 'vg-uuid' } }])

      allow(vol_group_manager).to receive(:detach_from_vm)
        .with('vg-uuid', 'vm_id')
        .and_return('detached')

      allow(vm_manager).to receive(:set_power_state)
        .with('vm_id', 'off')
        .and_return('task_id')
    end
    context 'when delete succeeds' do
      it 'deletes a vm' do
        allow(vm_manager).to receive(:delete_virtual_machine)
          .with('vm_id')
          .and_return('task_id')

        expect(cloud_obj.delete_vm('vm_id'))
          .to be true
      end
    end
    context 'when delete fails' do
      it 'raises error' do
        allow(vm_manager).to receive(:delete_virtual_machine)
          .with('vm_id')
          .and_raise

        expect { cloud_obj.delete_vm('vm_id') }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end
  end

  describe '#set_vm_metadata' do
    context 'when set vm meta data succeeds' do
      it 'returns true' do
        expect(cloud_obj.set_vm_metadata('vm_id', 'metadata'))
          .to be true
      end
    end
  end

  describe '#has_vm?' do
    context 'when get vm succeeds' do
      context 'vm is found' do
        it 'returns true' do
          allow(vm_manager).to receive(:get_virtual_machine)
            .with('vm_id')
            .and_return('vm_id')

          expect(cloud_obj.has_vm?('vm_id'))
            .to be true
        end
      end
      context 'vm is not found' do
        it 'returns false' do
          allow(vm_manager).to receive(:get_virtual_machine)
            .with('invalid_vm_id')

          expect(cloud_obj.has_vm?('invalid_vm_id'))
            .to be false
        end
      end
    end

    context 'when get vm fails' do
      it 'raises error' do
        allow(vm_manager).to receive(:get_virtual_machine)
          .with('vm_id')
          .and_raise

        expect(cloud_obj.has_vm?('vm_id'))
          .to be false
      end
    end
  end

  describe '#reboot_vm' do
    context 'when reboot succeeds' do
      context 'vm reboots' do
        it 'returns task id' do
          allow(vm_manager).to receive(:get_virtual_machine)
            .with('vm_id')
            .and_return('power_state' => 'off')

          allow(vm_manager).to receive(:set_power_state)
            .with('vm_id', 'on')
            .and_return('task_id')

          expect(cloud_obj.reboot_vm('vm_id'))
            .to eq('task_id')
        end
      end
    end
    context 'when reboot fails' do
      it 'raises error' do
        allow(vm_manager).to receive(:get_virtual_machine)
          .with('vm_id')
          .and_return('power_state' => 'OFF')

        allow(vm_manager).to receive(:set_power_state)
          .with('vm_id', 'acpi_reboot')
          .and_raise

        expect { cloud_obj.reboot_vm('vm_id') }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end
  end

  describe '#get_disks' do
    context 'when get disks succeeds' do
      it 'returns disk' do
        allow(vm_manager).to receive(:get_virtual_machine)
          .with('vm_id', true)
          .and_return('vm_disk_info' => [{ 'disk_address' =>
                      { 'volume_group_uuid' => 'vg-id' } }])

        expect(cloud_obj.get_disks('vm_id'))
          .to eq(['vg-id'])
      end
    end
    context 'when get disks fails' do
      it 'raises error' do
        allow(vm_manager).to receive(:get_virtual_machine)
          .with('vm_id', true)
          .and_raise

        expect { cloud_obj.get_disks('vm_id') }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end
  end

  describe '#create_disk' do
    before do
      allow(vol_group_manager).to receive(:create_volume_disk)
        .with('vg-uuid', 10_000, 'cont_uuid')
    end
    context 'when create disk succeeds' do
      it 'creates a disk' do
        allow(vol_group_manager).to receive(:create_volume_group)
          .with("bosh-peristent-disk-vm_id-#{rand(1000)}")
          .and_return('vg-uuid')

        expect(cloud_obj.create_disk(10_000, {}, 'vm_id'))
          .to eq('vg-uuid')
      end
    end
    context 'when create disk fails' do
      it 'raises error' do
        allow(vol_group_manager).to receive(:create_volume_group)
          .with("bosh-peristent-disk-vm_id-#{rand(1000)}")
          .and_raise

        expect { cloud_obj.create_disk(10_000, {}, 'vm_id') }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end
  end

  describe '#has_disk?' do
    context 'when has disk succeeds' do
      context 'disk is found' do
        it 'return true' do
          allow(vol_group_manager).to receive(:get_volume_group)
            .with('disk_id')
            .and_return('disk_exists')

          expect(cloud_obj.has_disk?('disk_id'))
            .to be true
        end
      end

      context 'disk is not found' do
        it 'returns false' do
          allow(vol_group_manager).to receive(:get_volume_group)
            .with('invalid_disk_id')

          expect(cloud_obj.has_disk?('invalid_disk_id'))
            .to be false
        end
      end
    end
    context 'when has disk fails' do
      it 'raises error' do
        allow(vol_group_manager).to receive(:get_volume_group)
          .with('disk_id')
          .and_raise

        expect(cloud_obj.has_disk?('disk_id'))
          .to be false
      end
    end
  end

  describe '#delete_disk' do
    context 'when delete disk succeeds' do
      it 'deletes the disk' do
        allow(vol_group_manager).to receive(:get_volume_group)
          .with('disk_id')
          .and_return('attachment_list' => [{ 'vm_uuid' => 'vm_id' }])

        allow(vol_group_manager).to receive(:delete_volume_group)
          .with('disk_id')
          .and_return('task_id')

        expect(cloud_obj.delete_disk('disk_id'))
          .to be true
      end
    end
    context 'when delete disk fails' do
      it 'raises error' do
        allow(vol_group_manager).to receive(:get_volume_group)
          .with('disk_id')
          .and_return('attachment_list' => [{ 'vm_uuid' => 'vm_id' }])

        allow(vol_group_manager).to receive(:delete_volume_group)
          .with('disk_id')
          .and_raise

        expect { cloud_obj.delete_disk('disk_id') }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end
  end

  describe '#detach_disk' do
    before do
      allow(vol_group_manager).to receive(:detach_from_vm)
        .with('disk_id', 'vm_id')
        .and_return('task_id')

      allow(vm_manager).to receive(:update_vm_description)
        .with('vm_id', get_vm_description)

      allow(vm_manager).to receive(:get_virtual_machine)
        .with('vm_id')
        .and_return(vm_spec('ide', 0, true, 'vg-uuid',
                            'device_bus' => 'SCSI',
                            'device_index' => 0,
                            'is_cdrom' => true,
                            'volume_group_uuid' => 'vg-uuid'))

      allow(vm_manager).to receive(:get_virtual_machine)
        .with('vm_id', true)
        .and_return(vm_spec('ide', 0, true, 'vg-uuid',
                            'device_bus' => 'SCSI',
                            'device_index' => 0,
                            'is_cdrom' => true,
                            'volume_group_uuid' => 'vg-uuid'))

      allow(image_manager).to receive(:get_image)
        .with('iso_uuid')
        .and_return('vm_disk_id' => 'iso_disk_id')

      allow(vm_manager).to receive(:load_iso)
        .with('vm_id', 'iso_disk_id')

      allow(image_manager).to receive(:delete_image)
        .with('iso_uuid')
        .and_return(true)

      allow(Dir).to receive(:mktmpdir).and_yield('tmp_path')

      allow_message_expectations_on_nil

      allow(ENV).to receive(:[])
        .with('PATH')
        .and_return('path')

      allow(File).to receive(:join)
        .with('path', 'genisoimage')
        .and_return('ls')

      allow(File).to receive(:exist?)
        .with('ls')
        .and_return(true)

      allow(File).to receive(:join)
        .with('tmp_path', 'env')
        .and_return('env_path')

      allow(File).to receive(:join)
        .with('tmp_path', 'env.iso')
        .and_return('iso_path')

      allow(File).to receive(:open)
        .with('env_path', 'w')
        .and_return(f)

      allow(f).to receive(:write)
        .with('env'.to_json)
        .and_return(f)

      allow(File).to receive(:open)
        .with('iso_path', 'r')
        .and_return(f)

      allow(f).to receive(:read)
        .and_return(f)

      allow($CHILD_STATUS).to receive(:exitstatus)
        .and_return(0)

      allow(image_manager).to receive(:create_image)
        .with('iso-image-vm_id', 'ISO_IMAGE', 'cont_uuid', 'iso_path')
        .and_return('iso_uuid')
    end
    context 'when detach disk succeeds' do
      context 'when volume group is attached to given vm' do
        before do
          allow(vol_group_manager).to receive(:get_volume_group)
            .with('disk_id')
            .and_return('attachment_list' => [{ 'vm_uuid' => 'vm_id' }])
        end
        it 'returns true' do
          expect(cloud_obj.detach_disk('vm_id', 'disk_id'))
            .to be true
        end
      end
      context 'when volume group is not attached to given vm' do
        before do
          allow(vol_group_manager).to receive(:get_volume_group)
            .with('disk_id')
            .and_return('attachment_list' => [{ 'vm_uuid' => 'other_vm_id' }])
        end
        it 'returns false' do
          expect(cloud_obj.detach_disk('vm_id', 'disk_id'))
            .to be nil
        end
      end
    end
    context 'when detach disk fails' do
      before do
        allow(vol_group_manager).to receive(:get_volume_group)
          .with('disk_id')
          .and_return('attachment_list' => [{ 'vm_uuid' => 'vm_id' }])
      end
      it 'raises error' do
        allow(vol_group_manager).to receive(:detach_from_vm)
          .with('disk_id', 'vm_id')
          .and_raise

        expect { cloud_obj.detach_disk('vm_id', 'disk_id') }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end
  end

  describe '#read_agent_settings' do
    context 'when get virtual machine succeeds' do
      it 'returns vm description' do
        allow(vm_manager).to receive(:get_virtual_machine)
          .with('vm_id')
          .and_return(vm_spec('ide', 0, true, 'vg-uuid',
                              'device_bus' => 'SCSI',
                              'device_index' => 0,
                              'is_cdrom' => true,
                              'volume_group_uuid' => 'vg-uuid'))

        expect(cloud_obj.read_agent_settings('vm_id'))
          .to eq(vm_description)
      end
    end
    context 'when get virtual machine with given id fails' do
      it 'raises error' do
        allow(vm_manager).to receive(:get_virtual_machine)
          .with('vm_id')
          .and_raise

        expect { cloud_obj.read_agent_settings('vm_id') }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#volume_group_attached?' do
    context 'when volume group is attached' do
      context 'when it is attached to given vm' do
        before do
          allow(vol_group_manager).to receive(:get_volume_group)
            .with('vg-uuid')
            .and_return('attachment_list' => [{ 'vm_uuid' => 'vm_id' }])
        end
        it 'returns true' do
          expect(cloud_obj.volume_group_attached?('vm_id', 'vg-uuid'))
            .to be true
        end
      end
      context 'when it is not attached to given vm' do
        before do
          allow(vol_group_manager).to receive(:get_volume_group)
            .with('vg-uuid')
            .and_return('attachment_list' => [{ 'vm_uuid' => 'other_vm_id' }])
        end
        it 'returns false' do
          expect(cloud_obj.volume_group_attached?('vm_id', 'vg-uuid'))
            .to be false
        end
      end
    end
    context 'when volume group is not attached' do
      before do
        allow(vol_group_manager).to receive(:get_volume_group)
          .with('vg-uuid')
          .and_return({})
      end
      it 'returns false' do
        expect(cloud_obj.volume_group_attached?('vm_id', 'vg-uuid'))
          .to be false
      end
    end
    context 'when get volume group fails' do
      before do
        allow(vol_group_manager).to receive(:get_volume_group)
          .with('vg-uuid')
          .and_raise
      end
      it 'raises error' do
        expect { cloud_obj.volume_group_attached?('vm_id', 'vg-uuid') }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#update_agent_settings' do
    before do
      allow(image_manager).to receive(:get_image)
        .with('iso_uuid')
        .and_return('vm_disk_id' => 'iso_disk_id')

      allow(vm_manager).to receive(:load_iso)
        .with('vm_id', 'iso_disk_id')

      allow(image_manager).to receive(:delete_image)
        .with('iso_uuid')
        .and_return(true)

      allow(Dir).to receive(:mktmpdir).and_yield('tmp_path')

      allow_message_expectations_on_nil

      allow(ENV).to receive(:[])
        .with('PATH')
        .and_return('path')

      allow(File).to receive(:join)
        .with('path', 'genisoimage')
        .and_return('ls')

      allow(File).to receive(:exist?)
        .with('ls')
        .and_return(true)

      allow(File).to receive(:join)
        .with('tmp_path', 'env')
        .and_return('env_path')

      allow(File).to receive(:join)
        .with('tmp_path', 'env.iso')
        .and_return('iso_path')

      allow(File).to receive(:open)
        .with('env_path', 'w')
        .and_return(f)

      allow(f).to receive(:write)
        .with('env'.to_json)
        .and_return(f)

      allow(File).to receive(:open)
        .with('iso_path', 'r')
        .and_return(f)

      allow(f).to receive(:read)
        .and_return(f)

      allow($CHILD_STATUS).to receive(:exitstatus)
        .and_return(0)

      allow(image_manager).to receive(:create_image)
        .with('iso-image-vm_id', 'ISO_IMAGE', 'cont_uuid', 'iso_path')
        .and_return('iso_uuid')

      allow(vm_manager).to receive(:get_virtual_machine)
        .with('vm_id')
        .and_return(vm_spec('ide', 0, true, 'vg-uuid',
                            'device_bus' => 'SCSI',
                            'device_index' => 0,
                            'is_cdrom' => true,
                            'volume_group_uuid' => 'vg-uuid'))

      allow(vm_manager).to receive(:update_vm_description)
        .with('vm_id', get_vm_description)
    end
    it 'updates agent settings' do
      expect(cloud_obj.update_agent_settings('vm_id') do |settings| end)
        .to be true
    end
  end

  describe '#update_settings' do
    before do
      allow(Dir).to receive(:mktmpdir).and_yield('tmp_path')

      allow_message_expectations_on_nil

      allow(ENV).to receive(:[])
        .with('PATH')
        .and_return('path')

      allow(File).to receive(:join)
        .with('path', 'genisoimage')
        .and_return('ls')

      allow(File).to receive(:exist?)
        .with('ls')
        .and_return(true)

      allow(described_class).to receive(:`)
        .with("'pathtobin' -o 'iso_path' 'env_path' 2>&1")

      allow(File).to receive(:join)
        .with('tmp_path', 'env')
        .and_return('env_path')

      allow(File).to receive(:join)
        .with('tmp_path', 'env.iso')
        .and_return('iso_path')

      allow(File).to receive(:open)
        .with('env_path', 'w')
        .and_return(f)

      allow(f).to receive(:write)
        .with('env'.to_json)
        .and_return(f)

      allow(File).to receive(:open)
        .with('iso_path', 'r')
        .and_return(f)

      allow(f).to receive(:read)
        .and_return(f)

      allow($CHILD_STATUS).to receive(:exitstatus)
        .and_return(0)

      allow(image_manager).to receive(:create_image)
        .with('iso-image-vm_id', 'ISO_IMAGE', 'cont_uuid', 'iso_path')
        .and_return('iso_uuid')

      allow(image_manager).to receive(:get_image)
        .with('iso_uuid')
        .and_return('vm_disk_id' => 'iso_disk_id')

      allow(vm_manager).to receive(:load_iso)
        .with('vm_id', 'iso_disk_id')

      allow(vm_manager).to receive(:update_vm_description)
        .with('vm_id', 'DO NOT DELETE "settings"')

      allow(image_manager).to receive(:delete_image)
        .with('iso_uuid')
        .and_return true
    end
    it 'updates the settings' do
      expect(cloud_obj.update_settings('vm_id', 'settings'))
        .to be true
    end
  end

  describe '#create_and_upload_env_iso' do
    before do
      allow(Dir).to receive(:mktmpdir).and_yield('tmp_path')

      allow_message_expectations_on_nil

      allow(ENV).to receive(:[])
        .with('PATH')
        .and_return('path')

      allow(File).to receive(:join)
        .with('path', 'genisoimage')
        .and_return('ls')

      allow(File).to receive(:exist?)
        .with('ls')
        .and_return(true)

      allow(described_class).to receive(:`)
        .with("'pathtobin' -o 'iso_path' 'env_path' 2>&1")

      allow(File).to receive(:join)
        .with('tmp_path', 'env')
        .and_return('env_path')

      allow(File).to receive(:join)
        .with('tmp_path', 'env.iso')
        .and_return('iso_path')

      allow(File).to receive(:open)
        .with('env_path', 'w')
        .and_return(f)

      allow(f).to receive(:write)
        .with('env'.to_json)
        .and_return(f)

      allow(File).to receive(:open)
        .with('iso_path', 'r')
        .and_return(f)

      allow(f).to receive(:read)
        .and_return(f)

      allow($CHILD_STATUS).to receive(:exitstatus)
        .and_return(0)
    end
    context 'when image creation succeeds' do
      it 'creates iso and uploads it' do
        allow(image_manager).to receive(:create_image)
          .with('iso-image-agent_id', 'ISO_IMAGE', 'cont_uuid', 'iso_path')
          .and_return('iso_uuid')
        expect(cloud_obj.create_and_upload_env_iso('agent_id', 'settings'))
          .to eq('iso_uuid')
      end
    end
    context 'when image creation fails' do
      it 'raises error' do
        allow(image_manager).to receive(:create_image)
          .with('iso-image-agent_id', 'ISO_IMAGE', 'cont_uuid', 'iso_path')
          .and_raise
        expect { cloud_obj.create_and_upload_env_iso('agent_id', 'settings') }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#snapshot_disk' do
    it 'raises Bosh::Clouds::NotSupported error' do
      expect { cloud_obj.snapshot_disk('disk_id', 'metadata') }
        .to raise_error(Bosh::Clouds::NotSupported)
    end
  end

  describe '#configure_networks' do
    it 'raises Bosh::Clouds::NotSupported error' do
      expect { cloud_obj.configure_networks('vm_id', 'network_spec') }
        .to raise_error(Bosh::Clouds::NotSupported)
    end
  end

  describe '#delete_snapshot' do
    it 'raises Bosh::Clouds::NotSupported error' do
      expect { cloud_obj.delete_snapshot('snapshot_id') }
        .to raise_error(Bosh::Clouds::NotSupported)
    end
  end

  describe '#create_vm_nic_config' do
    context 'when create vm nic config succeeds' do
      before do
        allow(client).to receive(:get)
          .with(API_VERSION, 'networks')
          .and_return('{"entities":[{"uuid":"vmnet_uuid","name":"vmnet"}]}')
      end
      it 'creates the network configuration for a vm' do
        expect(cloud_obj.create_vm_nic_config(network_spec))
          .to eq(network)
      end
    end
    context 'when create vm nic config fails' do
      before do
        allow(client).to receive(:get)
          .with(API_VERSION, 'networks')
          .and_raise
      end
      it 'raises error' do
        expect { cloud_obj.create_vm_nic_config(network_spec) }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#create_vm_specs' do
    it 'creates specifications to create a vm' do
      expect(cloud_obj.create_vm_specs('agent_id', 4, 16_384,
                                       agent_conf_ep, 'iso_disk_id',
                                       'stemcell_disk_id', network, 20_000))
        .to eq(vm_create_specs)
    end
  end

  describe '#create_vm' do
    before do
      allow(Dir).to receive(:mktmpdir).and_yield('tmp_path')

      allow_message_expectations_on_nil

      allow(ENV).to receive(:[])
        .with('PATH')
        .and_return('path')

      allow(File).to receive(:join)
        .with('path', 'genisoimage')
        .and_return('ls')

      allow(File).to receive(:exist?)
        .with('ls')
        .and_return(true)

      allow(described_class).to receive(:`)
        .with("'pathtobin' -o 'iso_path' 'env_path' 2>&1")

      allow(File).to receive(:join)
        .with('tmp_path', 'env')
        .and_return('env_path')

      allow(File).to receive(:join)
        .with('tmp_path', 'env.iso')
        .and_return('iso_path')

      allow(File).to receive(:open)
        .with('env_path', 'w')
        .and_return(f)

      allow(f).to receive(:write)
        .with('env'.to_json)
        .and_return(f)

      allow(File).to receive(:open)
        .with('iso_path', 'r')
        .and_return(f)

      allow(f).to receive(:read)
        .and_return(f)

      allow($CHILD_STATUS).to receive(:exitstatus)
        .and_return(0)

      allow(image_manager).to receive(:create_image)
        .with('iso-image-agent_id', 'ISO_IMAGE', 'cont_uuid', 'iso_path')
        .and_return('iso_uuid')

      allow(image_manager).to receive(:get_image)
        .with('iso_uuid')
        .and_return('vm_disk_id' => 'iso_disk_id')

      allow(image_manager).to receive(:get_image)
        .with('stemcell_id')
        .and_return('vm_disk_id' => 'stemcell_disk_id')

      allow(client).to receive(:get)
        .with(API_VERSION, 'networks')
        .and_return('{"entities":[{"uuid":"vmnet_uuid","name":"vmnet"}]}')

      allow(vm_manager).to receive(:set_power_state)
        .with('agent_id', 'on')

      allow(image_manager).to receive(:delete_image)
        .with('iso_uuid')

      allow(vm_manager).to receive(:get_virtual_machine)
        .with('agent_id')

      allow(vm_manager).to receive(:delete_virtual_machine)
        .with('agent_id')

      allow(vol_group_manager).to receive(:attach_to_vm)
        .with('existing_disk_id', 'agent_id')

      allow(vm_manager).to receive(:update_vm_description)
        .with('agent_id', get_vm_description)
    end
    context 'when vm creation succeeds' do
      it 'creates a vm' do
        allow(vm_manager).to receive(:create_virtual_machine)
          .with(vm_create_specs)

        expect(cloud_obj.create_vm('agent_id', 'stemcell_id',
                                   { 'cpu' => 4, 'disk' => 20_000,
                                     'ram' => 16_384 },
                                   network_spec, [], nil))
          .to eq('agent_id')
      end
      context 'when disk exists' do
        it 'creates a vm' do
          allow(vm_manager).to receive(:create_virtual_machine)
          .with(vm_create_specs)
          
          allow(vm_manager).to receive(:create_virtual_machine)
            .with(vm_create_specs_with_existing_disk)

          allow(vol_group_manager).to receive(:get_volume_group)
            .with('existing_disk_id')
            .and_return({})

          allow(vm_manager).to receive(:get_virtual_machine)
            .with('agent_id')
            .and_return(vm_spec('"existing_disk_id":"/dev/sdc"'))

          allow(vm_manager).to receive(:get_virtual_machine)
            .with('agent_id', true)
            .and_return(vm_spec('"existing_disk_id":"/dev/sdc"'))

          allow(vm_manager).to receive(:load_iso)
            .with('agent_id', 'iso_disk_id')

          allow(vm_manager).to receive(:update_vm_description)
            .with('agent_id', get_vm_description('"existing_disk_id":"/dev/sdc"'))

          expect(cloud_obj.create_vm('agent_id', 'stemcell_id',
                                     { 'cpu' => 4, 'disk' => 20_000,
                                       'ram' => 16_384 },
                                     network_spec, ['existing_disk_id'], nil))
            .to eq('agent_id')
        end
      end
    end
    context 'when vm creation fails' do
      it 'raises error' do
        allow(image_manager).to receive(:get_image)
          .with('stemcell_id')
          .and_raise

        allow(vm_manager).to receive(:create_virtual_machine)
          .with(vm_create_specs)

        expect do
          cloud_obj.create_vm('agent_id', 'stemcell_id',
                              { 'cpu' => 4, 'disk' => 20_000,
                                'ram' => 16_384 },
                              network_spec, [], nil)
        end
          .to raise_error(Bosh::Clouds::CloudError)
      end
      context 'when create virtual machine fails' do
        it 'raises error' do
          allow(vm_manager).to receive(:create_virtual_machine)
            .with(vm_create_specs)
            .and_raise(Bosh::Clouds::VMCreationFailed)

          expect do
            cloud_obj.create_vm('agent_id', 'stemcell_id',
                                { 'cpu' => 4, 'disk' => 20_000,
                                  'ram' => 16_384 },
                                network_spec, [], nil)
          end
            .to raise_error(Bosh::Clouds::CloudError)
        end
      end
    end
  end

  describe '#attach_disk' do
    before do
      allow(vol_group_manager).to receive(:attach_to_vm)
        .with('disk_id', 'vm_id')

      allow(vm_manager).to receive(:get_virtual_machine)
        .with('vm_id')
        .and_return(vm_spec('ide', 0, true, 'vg-uuid',
                            'device_bus' => 'SCSI',
                            'device_index' => 0,
                            'is_cdrom' => true,
                            'volume_group_uuid' => 'vg-uuid'))

      allow(vm_manager).to receive(:get_virtual_machine)
        .with('vm_id', true)
        .and_return(vm_spec('ide', 0, true, 'vg-uuid',
                            'device_bus' => 'SCSI',
                            'device_index' => 0,
                            'is_cdrom' => true,
                            'volume_group_uuid' => 'vg-uuid'))

      allow(image_manager).to receive(:get_image)
        .with('iso_uuid')
        .and_return('vm_disk_id' => 'iso_disk_id')

      allow(vm_manager).to receive(:load_iso)
        .with('vm_id', 'iso_disk_id')

      allow(image_manager).to receive(:delete_image)
        .with('iso_uuid')
        .and_return(true)

      allow(Dir).to receive(:mktmpdir).and_yield('tmp_path')

      allow_message_expectations_on_nil

      allow(ENV).to receive(:[])
        .with('PATH')
        .and_return('path')

      allow(File).to receive(:join)
        .with('path', 'genisoimage')
        .and_return('ls')

      allow(File).to receive(:exist?)
        .with('ls')
        .and_return(true)

      allow(File).to receive(:join)
        .with('tmp_path', 'env')
        .and_return('env_path')

      allow(File).to receive(:join)
        .with('tmp_path', 'env.iso')
        .and_return('iso_path')

      allow(File).to receive(:open)
        .with('env_path', 'w')
        .and_return(f)

      allow(f).to receive(:write)
        .with('env'.to_json)
        .and_return(f)

      allow(File).to receive(:open)
        .with('iso_path', 'r')
        .and_return(f)

      allow(f).to receive(:read)
        .and_return(f)

      allow($CHILD_STATUS).to receive(:exitstatus)
        .and_return(0)

      allow(image_manager).to receive(:create_image)
        .with('iso-image-vm_id', 'ISO_IMAGE', 'cont_uuid', 'iso_path')
        .and_return('iso_uuid')

      allow(vm_manager).to receive(:update_vm_description)
        .with('vm_id', get_vm_description('"disk_id":"/dev/sdc"'))
    end
    context 'when the disk is already attached to the given vm' do
      before do
        allow(vol_group_manager).to receive(:get_volume_group)
          .with('disk_id')
          .and_return('attachment_list' => [{ 'vm_uuid' => 'vm_id' }])
      end
      it 'skips attaching the disk' do
        expect(cloud_obj.attach_disk('vm_id', 'disk_id'))
          .to be nil
      end
    end
    context 'when the disk is not already attached to the given vm' do
      before do
        allow(vm_manager).to receive(:update_vm_description)
          .with('vm_id', get_vm_description('"existing_disk_id":"/dev/sdc"'))

        allow(vol_group_manager).to receive(:get_volume_group)
          .with('disk_id')
          .and_return({})
      end
      it 'attaches the disk to the vm' do
        expect(cloud_obj.attach_disk('vm_id', 'disk_id'))
          .to be true
      end
    end
    context 'when delete image fails' do
      before do
        allow(vol_group_manager).to receive(:get_volume_group)
          .with('disk_id')
          .and_return({})

        allow(image_manager).to receive(:delete_image)
          .with('iso_uuid')
          .and_raise
      end
      it 'raises error' do
        expect { cloud_obj.attach_disk('vm_id', 'disk_id') }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end
  end
end

def vm_spec(device_bus = 'scsi', device_index = 1, is_cdrom = false, volume_group_uuid = 'disk_id', source_disk_address = nil, existing_disk = "")
  { 'description' => 'DO NOT DELETE {"vm":{"name":"agent_id"},"agent_id":"agent_id",
    "environment":null,"blobstore":{"options":{"blobstore_path":
    "/var/vcap/micro_bosh/data/cache",
    "path":"/var/vcap/micro_bosh/data/cache"},"provider":"local"},
    "mbus":"https://username:password@10.0.0.1:6868",
    "networks":{"default":{"cloud_properties":{"subnet":"vmnet"},
    "default":["dns","gateway"],
    "dns":["10.5.4.22"],"gateway":"10.5.136.1",
    "ip":"10.0.0.1","netmask":"255.255.252.0",
    "type":"manual"}},
    "disks":{"system":"/dev/sda","ephemeral":"/dev/sdb",
    "persistent":{' + existing_disk + '}}}',
    'vm_disk_info' => [
      { 'disk_address' => { 'device_bus' => device_bus,
                            'device_index' => device_index,
                            'is_cdrom' => is_cdrom,
                            'volume_group_uuid' => volume_group_uuid },
        'is_cdrom' => is_cdrom,
        'is_empty' => true,
        'size' => 0,
        'source_disk_address' => source_disk_address,
        'storage_container_uuid' => 'cont_uuid' }
    ] }
end

def get_description(parameter = "")
  'DO NOT DELETE {"vm":{"name":"agent_id"},' \
                    '"agent_id":"agent_id",' \
                    '"environment":null,' \
                    '"blobstore":{"options":{"blobstore_path":' \
                    '"/var/vcap/micro_bosh/data/cache",' \
                    '"path":"/var/vcap/micro_bosh/data/cache"},' \
                    '"provider":"local"},'\
                    '"mbus":"https://username:password@10.0.0.1:6868",'\
                    '"networks":{"default":{"cloud_properties":{"subnet":"vmnet"},' \
                    '"default":["dns","gateway"],"dns":["10.5.4.22"],' \
                    '"gateway":"10.5.136.1","ip":"10.0.0.1",' \
                    '"netmask":"255.255.252.0","type":"manual"}},' \
                    '"disks":{"system":"/dev/sda",' \
                    '"persistent":{' + parameter + '},"ephemeral":"/dev/sdb"}}'
end

def get_vm_description(existing_disk = "")
  'DO NOT DELETE {"vm":{"name":"agent_id"},' \
                    '"agent_id":"agent_id",' \
                    '"environment":null,' \
                    '"blobstore":{"options":{"blobstore_path":' \
                    '"/var/vcap/micro_bosh/data/cache",' \
                    '"path":"/var/vcap/micro_bosh/data/cache"},' \
                    '"provider":"local"},'\
                    '"mbus":"https://username:password@10.0.0.1:6868",'\
                    '"networks":{"default":{"cloud_properties":{"subnet":"vmnet"},' \
                    '"default":["dns","gateway"],"dns":["10.5.4.22"],' \
                    '"gateway":"10.5.136.1","ip":"10.0.0.1",' \
                    '"netmask":"255.255.252.0","type":"manual"}},' \
                    '"disks":{"system":"/dev/sda",' \
                    '"ephemeral":"/dev/sdb","persistent":{'+ existing_disk +'}}}'
end
