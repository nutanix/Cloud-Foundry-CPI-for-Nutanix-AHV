require 'yaml'
require 'ostruct'
require 'spec_helper'
require 'securerandom'

class IntegrationConfig
  attr_reader :logger,
              :stemcell_path,
              :subnet,
              :manual_ip,
              :gateway,
              :dns,
              :netmask,
              :resource_pool,
              :vm_id,
              :temp_vm_id,
              :invalid_vm_id,
              :cloud_options,
              :cloud_options_with_invalid_container_name

  def initialize
    config = LifecycleHelper.getconfig
    @username = config['ACCESS_USERNAME']
    @passwd = config['ACCESS_PASSWORD']
    @endpoint = config['ACCESS_ENDPOINT']
    @cloud_properties = config['cloud_properties']
    @ntp = config['ntp']
    @gateway = config['gateway']
    @netmask = config['netmask']
    @dns = config['dns']
    @subnet = config['subnet']
    @cpu = config['resource_pool'].first['cpu']
    @disk = config['resource_pool'].first['disk']
    @ram = config['resource_pool'].first['ram']
    @resource_pool = resource_pool
    @stemcell_path = config['STEMCELL_PATH']
    @container_name = config['container_name']
    @manual_ip = config['manual_ip']
    @logger  = Logger.new(nil)
    @cloud_options = cloud_option(config['container_name'])['options']
    @cloud_options_with_invalid_container_name = cloud_option('invalid_container_name')['options']
    @vm_id = SecureRandom.uuid
    @temp_vm_id = SecureRandom.uuid
    @invalid_vm_id = SecureRandom.uuid
    Bosh::Clouds::Config.configure(OpenStruct.new(:logger => @logger))
  end

  def create_cpi
    @cpi = Bosh::AcropolisCloud::Cloud.new(@cloud_options)
  end

  def create_cpi_with_invalid_container_name
    @invalid_cpi = Bosh::AcropolisCloud::Cloud.new(@cloud_options_with_invalid_container_name)
  end

  def cloud_option(container_name)
    { 'options' => {
        'user' => @username,
        'password' => @passwd,
        'endpoint' => @endpoint,
        'container_name' => container_name,
        'ntp' => @ntp,
        'agent' => { 'mbus' => 'https://username:password@10.0.0.1:6868' },  
        'blobstore' => { 'options' => { 'blobstore_path' => 
                    '/var/vcap/micro_bosh/data/cache',
                    'path' => '/var/vcap/micro_bosh/data/cache' },
                    'provider' => 'local'  } } }
  end

  def cloud_properties
    { 'name' => 'test-stemcell', # This can be any random name and we need not take it from any config file.
      'version' => '1.0',
      'container_name' => @container_name }
  end

  def resource_pool
    { 'cpu' => @cpu, 'disk' => @disk, 'ram' => @ram }
  end
end
