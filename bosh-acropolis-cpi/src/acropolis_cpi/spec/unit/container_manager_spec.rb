require 'spec_helper'
require 'cloud/acropolis/container_manager'
require 'cloud/acropolis/cloud'

describe Bosh::AcropolisCloud::NutanixContainerManager do
  subject(:cont_mgr_obj) { described_class.new(client, logger) }
  let(:logger) { Bosh::Clouds::Config.logger }
  let(:client) { instance_double('Bosh::AcropolisCloud::NutanixRestClient') }
  let(:output) do
    '{"entities" :
    [{"storage_container_uuid": "1234","name": "c_name","id" : "id1234"},
    {"storage_container_uuid": "1235","name": "c_name1","id" : "id12341"},
    {"storage_container_uuid": "1236","name": "c_name2","id" : "id12::34"}]}'
  end

  before do
    allow(client).to receive(:get)
      .with(API_VERSION, 'storage_containers/1234')
      .and_return('{"uuid": "1234"}')

    allow(client).to receive(:get)
      .with(API_VERSION, 'storage_containers/12345')
      .and_return(nil)

    allow(client).to receive(:get)
      .with(API_VERSION, 'storage_containers/1XXX')
      .and_raise

    allow(client).to receive(:get)
      .with(API_VERSION, 'storage_containers')
      .and_return(output)
  end

  describe '#get_container' do
    context 'when container exists' do
      it 'gets a container' do
        expect(cont_mgr_obj.get_container('1234')).to eq('uuid' => '1234')
      end
    end
    context 'when container does not exist' do
      it 'does not return a container' do
        expect(cont_mgr_obj.get_container('12345')).to eq(nil)
      end
    end
    context 'when get container fails' do
      it 'raises error' do
        expect { cont_mgr_obj.get_container('1XXX') }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#get_container_uuid_by_name' do
    context 'when specified name of container exists' do
      it 'gets the container uuid' do
        expect(cont_mgr_obj.get_container_uuid_by_name('c_name')).to eq('1234')
      end
    end
    context 'when specified name of container does not exist' do
      it 'raises error' do
        expect { cont_mgr_obj.get_container_uuid_by_name('invalid_container_name') }
          .to raise_error(RuntimeError)
      end
    end
    context 'when get conatiner uuid fails' do
      it 'raises an error' do
        allow(client).to receive(:get).with(API_VERSION, 'storage_containers')
          .and_raise
        expect { cont_mgr_obj.get_container_uuid_by_name('') }
          .to raise_error(RuntimeError)
      end
    end
  end
end
