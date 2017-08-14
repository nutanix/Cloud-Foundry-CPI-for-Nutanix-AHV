require 'spec_helper'
require 'cloud/acropolis/image_manager'
require 'cloud/acropolis/cloud'

describe Bosh::AcropolisCloud::NutanixImageManager do
  subject(:img_mgr_obj) { described_class.new(client, logger) }

  let(:logger) { Bosh::Clouds::Config.logger }
  let(:client) { instance_double('Bosh::AcropolisCloud::NutanixRestClient') }
  let(:f) { 'file_name' }

  before do
    allow(File).to receive(:open).with('C://localimg')
      .and_return('file_name')

    allow(Bosh::AcropolisCloud::TaskManager).to receive(:wait_on_task)
      .with('task_id', client, logger)
      .and_return('task_id')

    allow(client).to receive(:post)
      .with(API_VERSION,
            'images',
            create_image_specs('img_name', 'http://imgurl').to_json)
      .and_return('{"task_uuid" : "task_id"}')

    allow(client).to receive(:post)
      .with(API_VERSION,
            'images',
            create_image_specs('img_name1', 'http://imgurl').to_json)
      .and_raise

    allow(client).to receive(:post)
      .with(API_VERSION,
            'images',
            create_image_specs('img_name1', 'C://localimg').to_json)
      .and_raise

    allow(client).to receive(:post)
      .with(API_VERSION,
            'images',
            create_image_specs('img_name', 'nfs://localimg').to_json)
      .and_return('{"task_uuid" : "task_id"}')

    allow(client).to receive(:post)
      .with(API_VERSION,
            'images',
            create_image_specs('img_name1', 'nfs://localimg').to_json)
      .and_raise

    allow(client).to receive(:post)
      .with(API_VERSION, 'images',
            { name: 'img_name', image_type: 'img_type',
              annotation: 'img_name' }.to_json)
      .and_return('{"task_uuid" : "task_id"}')

    allow(client).to receive(:post)
      .with(API_VERSION, 'images',
            { name: 'img_name11', image_type: 'img_type',
              annotation: 'img_name11' }.to_json)
      .and_raise

    allow(Bosh::AcropolisCloud::TaskManager).to receive(:wait_on_task)
      .with('task_id', client, logger, 3600)
      .and_return('task_id')

    allow(client).to receive(:get)
      .with(API_VERSION, 'storage_containers/cont_uuid::c_id')
      .and_return('{"id" : "cont_uuid::c_id"}')

    allow(client).to receive(:put)
      .with('v0.8', 'images/task_id/upload', f, nil,
            'X-Nutanix-Destination-Container' => 'c_id')
      .and_return('{"task_uuid" : "task_id"}')

    allow(client).to receive(:delete).with(API_VERSION, 'images/image_uuid')
      .and_return('{"task_uuid" : "task_id"}')

    allow(client).to receive(:delete).with(API_VERSION, 'images/image_uuid1')
      .and_raise

    allow(client).to receive(:get).with(API_VERSION, 'images/image_uuid')
      .and_return('{"image_uuid": "image_uuid"}')

    allow(client).to receive(:get).with(API_VERSION, 'images/image_uuid1')
      .and_raise
  end

  describe '#create_image' do
    context 'when image creation succeeds' do
      context 'when http url is specified' do
        it 'uses http url to create an image' do
          expect(img_mgr_obj.create_image('img_name', 'img_type',
                                          'cont_uuid::c_id',
                                          'http://imgurl'))
            .to eq('task_id')
        end
      end
      context 'when nfs url is specified' do
        it 'uses nfs url to create an image' do
          expect(img_mgr_obj.create_image('img_name', 'img_type',
                                          'cont_uuid::c_id',
                                          'nfs://localimg'))
            .to eq('task_id')
        end
      end
      context 'when local path is specified' do
        it 'uses local path to create the image' do
          expect(img_mgr_obj.create_image('img_name', 'img_type',
                                          'cont_uuid::c_id',
                                          'C://localimg'))
            .to eq('task_id')
        end
      end
    end
    context 'when image creation fails' do
      context 'when image is created with http url' do
        it 'raises error' do
          expect do
            img_mgr_obj.create_image('img_name1', 'img_type',
                                     'cont_uuid::c_id', 'http://imgurl')
          end
            .to raise_error(RuntimeError)
        end
      end
      context 'when image is created using nfs url' do
        it 'raises error' do
          expect do
            img_mgr_obj.create_image('img_name1', 'img_type',
                                     'cont_uuid::c_id', 'nfs://localimg')
          end
            .to raise_error(RuntimeError)
        end
      end
    end
  end

  describe '#delete_image' do
    context 'when image deletion succeeds' do
      it 'deletes the image' do
        expect(img_mgr_obj.delete_image('image_uuid'))
          .to eq(true) # logger.debug
      end
    end
    context 'when image deletion fails' do
      it 'raises error' do
        expect { img_mgr_obj.delete_image('image_uuid1') }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#get_image' do
    context 'when getting the image succeeds' do
      it 'gets an image' do
        expect(img_mgr_obj.get_image('image_uuid'))
          .to eq('image_uuid' => 'image_uuid')
      end
    end
    context 'when getting the image fails' do
      it 'raises error' do
        expect { img_mgr_obj.get_image('image_uuid1') }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#create_image_with_url' do
    context 'when create image succeeds' do
      it 'creates image using http url of remote location' do
        expect(img_mgr_obj.create_image_with_url('img_name', 'img_type',
                                                 'cont_uuid::c_id',
                                                 'http://imgurl'))
          .to eq('task_id')
      end
      it 'creates image using nfs url of remote location' do
        expect(img_mgr_obj.create_image_with_url('img_name', 'img_type',
                                                 'cont_uuid::c_id',
                                                 'nfs://localimg'))
          .to eq('task_id')
      end
    end
    context 'when create image fails' do
      it 'raises error' do
        expect do
          img_mgr_obj.create_image_with_url('img_name1', 'img_type',
                                            'cont_uuid::c_id', 'http://imgurl')
        end
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#create_image_with_local' do
    context 'when create image succeeds' do
      it 'creates image using path of local location' do
        expect(img_mgr_obj.create_image_with_local('img_name',
                                                   'img_type',
                                                   'cont_uuid::c_id',
                                                   'C://localimg'))
          .to eq('task_id')
      end
    end
    context 'when create image fails' do
      it 'creates image using path of local location' do
        expect do
          img_mgr_obj.create_image_with_local('img_name11', 'img_type',
                                              'cont_uuid::c_id', 'C://localimg')
        end
          .to raise_error(RuntimeError)
      end
    end
  end
end

def create_image_specs(name, url)
  { name: name, annotation: name, image_type: 'img_type',
    image_import_spec: { storage_container_uuid: 'cont_uuid::c_id',
                         url: url } }
end
