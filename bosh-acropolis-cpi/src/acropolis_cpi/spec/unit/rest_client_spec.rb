require 'spec_helper'
require 'cloud/acropolis/rest_client'
require 'cloud/acropolis/cloud'

describe Bosh::AcropolisCloud::NutanixRestClient do
  subject(:rest_client_obj) do
    described_class.new(MOCK_ACCESS_ENDPOINT, MOCK_ACCESS_USERNAME,
                        MOCK_ACCESS_PASSWORD, logger)
  end

  let(:logger) { Bosh::Clouds::Config.logger }

  let(:options_to_call) do
    { method: :get,
      url: 'https://10.0.0.1:9440/api/nutanix/v2.0/images',
      headers: { content_type: 'json', accept: 'json' },
      timeout: 600,
      verify_ssl: false,
      user: MOCK_ACCESS_USERNAME,
      password: MOCK_ACCESS_PASSWORD }
  end

  before do
    allow(RestClient::Request).to receive(:execute)
      .with(client_params(:get, 'https://10.0.0.1:9440/api/nutanix/v2.0/images'))
      .and_return('200')

    allow(RestClient::Request).to receive(:execute)
      .with(client_params(:get, 'https://10.0.0.1:9440/api/nutanix/v2.0/invalid_parameter'))
      .and_raise

    allow(RestClient::Request).to receive(:execute)
      .with(client_params_with_payload(:post, 'https://10.0.0.1:9440/api/nutanix/v2.0/images'))
      .and_return('200')

    allow(RestClient::Request).to receive(:execute)
      .with(client_params(:delete, 'https://10.0.0.1:9440/api/nutanix/v2.0/images'))
      .and_return('200')

    allow(RestClient::Request).to receive(:execute)
      .with(client_params_with_payload(:put, 'https://10.0.0.1:9440/api/nutanix/v2.0/images'))
      .and_return('200')
  end

  describe '#get' do
    it 'performs get API operation' do
      expect(rest_client_obj.get(API_VERSION, 'images')).to eq('200')
    end
  end

  describe '#post' do
    it 'performs post API operation' do
      expect(rest_client_obj.post(API_VERSION,
                                  'images', payload: 'payload'))
        .to eq('200')
    end
  end

  describe '#delete' do
    it 'performs delete API operation' do
      expect(rest_client_obj.delete(API_VERSION, 'images')).to eq('200')
    end
  end

  describe '#put' do
    it 'performs put API operation' do
      expect(rest_client_obj.put(API_VERSION,
                                 'images', payload: 'payload'))
        .to eq('200')
    end
  end

  describe '#uri_builder' do
    context 'when query params are not given' do
      it 'generates the uri' do
        expect(rest_client_obj.uri_builder(API_VERSION, 'images', nil))
          .to eq('https://10.0.0.1:9440/api/nutanix/v2.0/images')
      end
    end
    context 'when query params are given' do
      it 'generates uri having query params' do
        expect(rest_client_obj.uri_builder(API_VERSION,
                                           'vms', include_vm_disk_config: true))
          .to eq('https://10.0.0.1:9440/api/nutanix/v2.0/vms?include_vm_disk_config=true')
      end
    end
  end

  describe '#call_options_builder' do
    it 'builds options required for making a REST call' do
      expect(rest_client_obj
        .call_options_builder(:get,
                              'https://10.0.0.1:9440/api/nutanix/v2.0/images',
                              nil, nil))
        .to eq(options_to_call)
    end
  end

  describe '#make_rest_call' do
    context 'when valid parameters are passed' do
      it 'makes the rest call' do
        expect(rest_client_obj
                .make_rest_call(:get,
                                'https://10.0.0.1:9440/api/nutanix/v2.0/images',
                                nil, nil))
          .to eq('200')
      end
    end
    context 'when invalid parameters are passed' do
      it 'raises error' do
        expect do
          rest_client_obj
            .make_rest_call(:get,
                            'https://10.0.0.1:9440/api/nutanix/v2.0/invalid_parameter',
                            nil, nil)
        end
          .to raise_error(RuntimeError)
      end
    end
  end
end

def client_params(method_name, url)
  { method: method_name,
    url: url,
    headers: { content_type: 'json', accept: 'json' },
    timeout: 600,
    verify_ssl: false,
    user: MOCK_ACCESS_USERNAME,
    password: MOCK_ACCESS_PASSWORD }
end

def client_params_with_payload(method_name, url)
  { method: method_name,
    url: url,
    headers: { content_type: 'json', accept: 'json' },
    timeout: 600,
    verify_ssl: false,
    user: MOCK_ACCESS_USERNAME,
    password: MOCK_ACCESS_PASSWORD,
    payload: { payload: 'payload' } }
end
