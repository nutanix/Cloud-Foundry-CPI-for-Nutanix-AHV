require 'spec_helper'
require 'cloud/acropolis/volume_group_manager'
require 'cloud/acropolis/cloud'

describe Bosh::AcropolisCloud::NutanixVolumeGroupManager do
  subject(:vol_mgr_obj) { described_class.new(client, logger) }

  let(:client) { instance_double('Bosh::AcropolisCloud::NutanixRestClient') }
  let(:logger) { Bosh::Clouds::Config.logger }

  before do
    allow(Bosh::AcropolisCloud::TaskManager).to receive(:wait_on_task)
      .with('task_id', client, logger)
      .and_return('task_id')

    allow(client).to receive(:delete)
      .with(API_VERSION,
            'volume_groups/volume_group_uuid')
      .and_return('{"task_uuid" : "task_id"}')

    allow(client).to receive(:delete)
      .with(API_VERSION,
            'volume_groups/volume_group_uuid1')
      .and_raise

    allow(client).to receive(:post)
      .with(API_VERSION,
            'volume_groups', { name: 'name' }.to_json)
      .and_return('{ "task_uuid" : "task_id" }')

    allow(client).to receive(:post)
      .with(API_VERSION,
            'volume_groups', { name: 'name1' }.to_json)
      .and_raise

    allow(client).to receive(:get)
      .with(API_VERSION,
            'volume_groups/volume_group_uuid', include_disk_size: true)
      .and_return('{ "vm_uuid" : "vm_uuid" }')

    allow(client).to receive(:get)
      .with(API_VERSION,
            'volume_groups/volume_group_uuid', include_disk_size: false)
      .and_return('{ "vm_uuid" : "vm_uuid" }')

    allow(client).to receive(:get)
      .with(API_VERSION,
            'volume_groups/volume_grp_uuid', include_disk_size: false)
      .and_raise

    allow(client).to receive(:post)
      .with(API_VERSION,
            'volume_groups/volume_group_uuid/attach',
            { vm_uuid: 'vm_uuid' }.to_json)
      .and_return('{ "task_uuid" : "task_id" }')

    allow(client).to receive(:post)
      .with(API_VERSION,
            'volume_groups/volume_group_uuid1/attach',
            { vm_uuid: 'vm_uuid' }.to_json)
      .and_raise

    allow(client).to receive(:post)
      .with(API_VERSION,
            'volume_groups/volume_group_uuid/detach',
            { vm_uuid: 'vm_uuid' }.to_json)
      .and_return('{"task_uuid" : "task_id"}')

    allow(client).to receive(:post)
      .with(API_VERSION,
            'volume_groups/volume_group_uuid1/detach',
            { vm_uuid: 'vm_uuid' }.to_json)
      .and_raise
  end

  describe '#create_volume_group' do
    context 'when create succeeds' do
      it 'creates a volume group' do
        expect(vol_mgr_obj.create_volume_group('name')).to eq('task_id')
      end
    end
    context 'when create fails' do
      it 'raises error' do
        expect { vol_mgr_obj.create_volume_group('name1') }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#delete_volume_group' do
    context 'when delete succeeds' do
      it 'deletes the volume group' do
        expect(vol_mgr_obj.delete_volume_group('volume_group_uuid'))
          .to eq('task_id')
      end
    end
    context 'when delete fails' do
      it 'raises error' do
        expect { vol_mgr_obj.delete_volume_group('volume_group_uuid1') }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#get_volume_group' do
    context 'when get succeeds' do
      context 'when disk size is included' do
        it 'gets the volume group' do
          expect(vol_mgr_obj.get_volume_group('volume_group_uuid', true))
            .to eq('vm_uuid' => 'vm_uuid')
        end
      end
      context 'when disk size is not included' do
        it 'gets the volume group' do
          expect(vol_mgr_obj.get_volume_group('volume_group_uuid'))
            .to eq('vm_uuid' => 'vm_uuid')
        end
      end
    end
    context 'when GET API fails' do
      it 'raises Bosh::Clouds::DiskNotFound error' do
        expect { vol_mgr_obj.get_volume_group('volume_grp_uuid') }
          .to raise_error(Bosh::Clouds::DiskNotFound,
                          'Volume group volume_grp_uuid not found.')
      end
    end
  end

  describe '#attach_to_vm' do
    context 'when attach succeeds' do
      it 'attaches volume group to vm' do
        expect(vol_mgr_obj.attach_to_vm('volume_group_uuid', 'vm_uuid'))
          .to eq('task_id')
      end
    end
    context 'when attach fails' do
      it 'raises Bosh::Clouds::DiskNotAttached error' do
        expect { vol_mgr_obj.attach_to_vm('volume_group_uuid1', 'vm_uuid') }
          .to raise_error(Bosh::Clouds::DiskNotAttached)
      end
    end
  end

  describe '#detach_from_vm' do
    context 'when detach succeeds' do
      it 'detaches a volume group from the vm' do
        expect(vol_mgr_obj.detach_from_vm('volume_group_uuid', 'vm_uuid'))
          .to eq('task_id')
      end
    end
    context 'when detach fails' do
      it 'raises Bosh::Clouds::DiskNotAttached error' do
        expect { vol_mgr_obj.detach_from_vm('volume_group_uuid1', 'vm_uuid') }
          .to raise_error(Bosh::Clouds::DiskNotAttached)
      end
    end
  end

  describe '#create_volume_disk' do
    before do
      allow(client).to receive(:post)
        .with(API_VERSION, 'volume_groups/volume_group_uuid/disks',
              { create_config:
                { size: 4 * 1_048_576,
                  storage_container_uuid: 'storage_container_uuid' } }
          .to_json)
        .and_return('{"task_uuid": "task_id"}')
      allow(client).to receive(:post)
        .with(API_VERSION, 'volume_groups/volume_group_uuid1/disks',
              { create_config:
                 { size: 4 * 1_048_576,
                   storage_container_uuid: 'storage_container_uuid' } }
          .to_json)
        .and_raise
    end
    context 'when create succeeds' do
      it 'creates a volume disk' do
        expect(vol_mgr_obj.create_volume_disk('volume_group_uuid', 4,
                                              'storage_container_uuid'))
          .to eq('task_id')
      end
    end
    context 'when create fails' do
      it 'raises error' do
        expect do
          vol_mgr_obj.create_volume_disk('volume_group_uuid1',
                                         4, 'storage_container_uuid')
        end
          .to raise_error(RuntimeError)
      end
    end
  end
end
