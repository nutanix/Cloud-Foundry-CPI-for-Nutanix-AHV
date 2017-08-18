require 'integration/integration_config'
require 'spec_helper'

describe Bosh::AcropolisCloud::Cloud do
  before(:all) do
    @conf = IntegrationConfig.new
    @cpi = @conf.create_cpi
    @stemcell_id = @cpi.create_stemcell(@conf.stemcell_path, @conf.cloud_options)
  end

  before { allow(Bosh::Clouds::Config).to receive(:logger).and_return(@conf.logger) }

  after(:all) do
    @cpi.delete_stemcell(@stemcell_id)
  end 

  context 'when invalid container name is used' do
    it 'raises error' do
      expect { @conf.create_cpi_with_invalid_container_name }
        .to raise_error(Bosh::Clouds::CloudError)
    end
  end

  describe 'manual network' do
    let(:network_spec) do
      {
        'default' => {
            'cloud_properties' => {
                'subnet' => @conf.subnet
            },
            'default' => %w(dns gateway),
            'dns' => @conf.dns,
            'gateway' => @conf.gateway,
            'ip' => @conf.manual_ip,
            'netmask' => @conf.netmask,
            'type' => 'manual'
          }
      }
    end

    let(:invalid_subnet_network_spec) do
      {
        'default' => {
            'cloud_properties' => {
                'subnet' => 'invalid_subnet'
            },
            'default' => %w(dns gateway),
            'dns' => @conf.dns,
            'gateway' => @conf.gateway,
            'ip' => @conf.manual_ip,
            'netmask' => @conf.netmask,
            'type' => 'manual'
        }
      }
    end

    let(:network_spec_with_ip_out_of_subnet_range) do
      {
        'default' => {
            'cloud_properties' => {
                'subnet' => 'invalid_subnet'
            },
            'default' => %w(dns gateway),
            'dns' => @conf.dns,
            'gateway' => @conf.gateway,
            'ip' => '10.4.180.30',
            'netmask' => @conf.netmask,
            'type' => 'manual'
        }
      }
    end

    context 'with non-existing vlan network' do
      it 'raises error' do
        expect { vm_lifecycle(@stemcell_id, invalid_subnet_network_spec, []) }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end

    context 'with manual ip out of subnet range' do
      it 'raises error' do
        expect { vm_lifecycle(@stemcell_id, network_spec_with_ip_out_of_subnet_range, []) }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end

    context 'without existing disks' do
      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec, [])
        }.to_not raise_error
      end
    end

    context 'with existing disks' do
      before do
        @existing_disk_id = @cpi.create_disk(20000, {}, "fake_vm_id-#{rand(1000)}")
      end
      after do
        clean_up_disk(@existing_disk_id) if @existing_disk_id
      end

      it 'exercises the vm lifecycle' do
        expect {
        vm_lifecycle(@stemcell_id, network_spec, [@existing_disk_id])
        }.to_not raise_error
      end
    end

    describe 'attach_disk' do
      before do
        @vm_id = create_vm(@conf.vm_id, @stemcell_id, network_spec, [])
        @disk_id = @cpi.create_disk(20000, {}, @vm_id)
      end
      after do
        @cpi.detach_disk(@vm_id, @disk_id) if @disk_id
        clean_up_disk(@disk_id)
        clean_up_vm(@vm_id)
      end
      context 'when no disk is already attached' do
        it 'attaches the disk to vm' do
          expect { @cpi.attach_disk(@vm_id, @disk_id) }
            .to_not raise_error
        end
      end

      context 'when already attached disk is attached again' do
        it 'skips the attachment without raising any error' do
          expect { @cpi.attach_disk(@vm_id, @disk_id) }
            .to_not raise_error
          expect { @cpi.attach_disk(@vm_id, @disk_id) }
            .to_not raise_error
        end
      end
    end

    describe 'detach_disk' do
      context 'when detaching a disk that does not exist' do
        before do
          @temp_vm_id = create_vm(@conf.vm_id, @stemcell_id, network_spec, [])
          @non_existing_disk_id = 'fake_disk_id'
        end
        after do
          clean_up_vm(@temp_vm_id)
        end
        it 'raises error' do
          expect {  @cpi.detach_disk(@temp_vm_id,  @non_existing_disk_id) }
            .to raise_error(Bosh::Clouds::CloudError)
        end
      end
    end

    describe 'create_vm' do
      before do
        @temp_vm = create_vm(@conf.vm_id, @stemcell_id, network_spec, [])
      end
      after do
        clean_up_vm(@temp_vm)
      end
      context 'when VM created with an IP in use' do
        it 'should raise error' do
          expect { create_vm(@conf.temp_vm_id, @stemcell_id, network_spec, []) }
            .to raise_error(Bosh::Clouds::CloudError)
        end
      end
    end

    describe 'delete_vm' do
      context 'when deleting a non-existing vm' do
        it 'skips deletion and returns nil' do
          expect(@cpi.delete_vm(@conf.invalid_vm_id)).to be nil
        end
      end
    end

    context 'when referenced image does not exist' do
      it 'raises error' do
        expect { @cpi.create_stemcell('incorrect_stemcell_path', @conf.cloud_options) }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end

    context 'reattaching persistent disk' do
      before do
        @vm_id = create_vm(@conf.vm_id, @stemcell_id, network_spec, [])
        @disk_id = @cpi.create_disk(20000, {}, @vm_id)
      end
      after do
        clean_up_vm(@vm_id)
        clean_up_disk(@disk_id)
      end
      it 'reattaches the disk without locking cdrom' do
        @cpi.attach_disk(@vm_id, @disk_id)
        @cpi.detach_disk(@vm_id, @disk_id)
        @cpi.attach_disk(@vm_id, @disk_id)
        @cpi.detach_disk(@vm_id, @disk_id)
      end
    end

    context 'when persistent disk attached' do
      before do
        @vm_id = create_vm(@conf.vm_id, @stemcell_id, network_spec, [])
        @disk_id = @cpi.create_disk(20000, {}, @vm_id)
        @cpi.attach_disk(@vm_id, @disk_id)
      end
      after do
        clean_up_disk(@disk_id)
      end
      it 'can still find disk after deleting VM' do
        @cpi.delete_vm(@vm_id)
        expect(@cpi.has_disk?(@disk_id)).to be true
      end
    end

    context 'when no stemcell exists for the given stemcell id' do
      it 'raises error' do
        expect { @cpi.create_vm(@conf.vm_id, 'fake_stemcell_id',
                 @conf.resource_pool, network_spec, nil, nil) }
          .to raise_error(Bosh::Clouds::CloudError)
      end
    end
   end
end

def vm_lifecycle(stemcell_id, network_spec, disk = nil,
                 cloud_properties = {}, resource_pool = {})
  vm_id = create_vm(@conf.vm_id, stemcell_id, network_spec, disk)
  if disk.empty?
    disk_id = @cpi.create_disk(20000, cloud_properties, vm_id)
    expect(disk_id).to_not be_nil
    disk << disk_id
  end
  disk.each do |disk_id|
    expect(@cpi.has_disk?(disk_id)).to be true
    @cpi.attach_disk(vm_id, disk_id) 
    @cpi.detach_disk(vm_id, disk_id)
  end
rescue => e
  raise e
ensure
  disk.each { |disk_id| @cpi.delete_disk(disk_id) }
  clean_up_vm(vm_id)
end

def create_vm(agent_id, stemcell_id, network_spec, existing_disk = nil)
  vm_id = @cpi.create_vm(agent_id, @stemcell_id, @conf.resource_pool, network_spec, existing_disk, nil)
  expect(vm_id).to_not be_nil
  expect(@cpi.has_vm?(vm_id)).to be true
  @cpi.set_vm_metadata('vm_id', {})
  vm_id
end

def clean_up_disk(disk_id)
  @cpi.delete_disk(disk_id) if disk_id 
end

def clean_up_vm(vm_id)
  @cpi.delete_vm(vm_id)  if vm_id
end
