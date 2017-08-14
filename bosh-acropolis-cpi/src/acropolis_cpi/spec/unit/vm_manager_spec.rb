require 'spec_helper'
require 'cloud/acropolis/vm_manager'
require 'cloud/acropolis/cloud'

describe Bosh::AcropolisCloud::NutanixVirtualMachineManager do
  subject(:vm_mgr_obj) { described_class.new(client, logger) }

  let(:logger) { Bosh::Clouds::Config.logger }
  let(:client) { instance_double('Bosh::AcropolisCloud::NutanixRestClient') }

  before do
    allow(Bosh::AcropolisCloud::TaskManager).to receive(:wait_on_task)
      .with('task_id', client, logger)
      .and_return('task_id')

    allow(client).to receive(:post)
      .with(API_VERSION,
            'vms/vm_uuid/set_power_state',
            { transition: 'OFF' }.to_json)
      .and_return('{"task_uuid" : "task_id"}')

    allow(client).to receive(:post)
      .with(API_VERSION,
            'vms/vm_uuid1/set_power_state',
            { transition: 'OFF' }.to_json)
      .and_raise

    allow(client).to receive(:post)
      .with(API_VERSION, 'vms', {}.to_json)
      .and_return('{"task_uuid": "task_id"}')

    allow(client).to receive(:post)
      .with(API_VERSION, 'vms',
            '{"vm": "vm"}'.to_json)
      .and_raise

    allow(client).to receive(:get)
      .with(API_VERSION, 'vms/1234',
            include_vm_disk_config: false, include_vm_nic_config: false)
      .and_return('{"uuid": "1234"}')

    allow(client).to receive(:get)
      .with(API_VERSION, 'vms/1XXX',
            include_vm_disk_config: false, include_vm_nic_config: false)
      .and_raise

    allow(client).to receive(:delete)
      .with(API_VERSION, 'vms/1234')
      .and_return('{"task_uuid": "task_id"}')

    allow(client).to receive(:delete)
      .with(API_VERSION, 'vms/1XXX')
      .and_raise

    allow(client).to receive(:put)
      .with('v0.8', 'vms/vm_uuid/disks/ide-0',
            { updateSpec: { isEmpty: false,
                            vmDiskClone: { vmDiskUuid:
                                           'vm_disk_id' } } }.to_json)
      .and_return('{"taskUuid": "task_id"}')

    allow(client).to receive(:put)
      .with('v0.8', 'vms/vm_uuid1/disks/ide-0',
            { updateSpec: { isEmpty: false,
                            vmDiskClone: { vmDiskUuid:
                                           'vm_disk_id1' } } }.to_json)
      .and_raise
  end

  describe '#get_virtual_machine' do
    context 'when get succeeds' do
      it 'gets the virtual machine' do
        expect(vm_mgr_obj.get_virtual_machine('1234'))
          .to eq('uuid' => '1234')
      end
    end
    context 'when get fails' do
      it 'raises error' do
        expect { vm_mgr_obj.get_virtual_machine('1XXX') }
          .to raise_error(Bosh::Clouds::VMNotFound, 'VM with id 1XXX not found.')
      end
    end
  end

  describe '#delete_virtual_machine' do
    context 'when delete succeeds' do
      it 'deletes a virtual machine' do
        expect(vm_mgr_obj.delete_virtual_machine('1234'))
          .to eq('task_id')
      end
    end
    context 'when delete fails' do
      it 'raises error' do
        expect { vm_mgr_obj.delete_virtual_machine('1XXX') }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#set_power_state' do
    context 'when power OFF succeeds' do
      it 'sets the power state' do
        expect(vm_mgr_obj.set_power_state('vm_uuid', 'OFF'))
          .to eq('task_id')
      end
    end
    context 'when power OFF fails' do
      it 'raises error' do
        expect { vm_mgr_obj.set_power_state('vm_uuid1', 'OFF') }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#create_virtual_machine' do
    context 'when create succeeds' do
      it 'creates a virtual machine' do
        expect(vm_mgr_obj.create_virtual_machine({}))
          .to eq('task_id')
      end
    end
    context 'when create fails' do
      it 'raises error' do
        expect { vm_mgr_obj.create_virtual_machine('{"vm": "vm"}') }
          .to raise_error(Bosh::Clouds::VMCreationFailed)
      end
    end
  end

  describe '#load_iso' do
    context 'when loading iso succeeds' do
      it 'loads the iso' do
        expect(vm_mgr_obj.load_iso('vm_uuid', 'vm_disk_id'))
          .to eq('task_id')
      end
    end
    context 'when loading iso fails' do
      it 'raises error' do
        expect { vm_mgr_obj.load_iso('vm_uuid1', 'vm_disk_id1') }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#update_vm_description' do
    context 'when update succeeds' do
      it 'updates the vm description' do
        allow(client).to receive(:put)
          .with(API_VERSION, 'vms/vm_uuid', "{\"description\":\"description\"}")
          .and_return('{"task_uuid":"task_id"}')

        expect(vm_mgr_obj.update_vm_description('vm_uuid', 'description'))
          .to eq('task_id')
      end
    end
    context 'when update fails' do
      it 'raises error' do
        allow(client).to receive(:put)
          .with(API_VERSION, 'vms/vm_uuid', "{\"description\":\"description\"}")
          .and_raise

        expect { vm_mgr_obj.update_vm_description('vm_uuid', 'description') }
          .to raise_error(RuntimeError)
      end
    end
  end
end
