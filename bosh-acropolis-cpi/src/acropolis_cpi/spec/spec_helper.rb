$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'simplecov'
project_root = File.expand_path('../../../..', __FILE__)
SimpleCov.coverage_dir(File.join(project_root, 'coverage'))
SimpleCov.start

require 'cloud/acropolis'
require 'cloud/acropolis/rest_client'
require 'cloud/acropolis/cloud'
require 'cloud/acropolis/vm_manager'

MOCK_ACCESS_USERNAME = 'user'
MOCK_ACCESS_PASSWORD = 'pwd'
API_VERSION = "v2.0"
MOCK_ACCESS_ENDPOINT = "https://10.0.0.1:9440/api/nutanix"


def mock_cloud_options
  {
    'options' => {
  'user' => MOCK_ACCESS_USERNAME,
  'password' => MOCK_ACCESS_PASSWORD,
  'endpoint' => MOCK_ACCESS_ENDPOINT,
  'container_name' => 'c_name',
  'ntp' => '1.2.3.4',
  'agent' => {"mbus"=>"https://username:password@10.0.0.1:6868"},  
  'blobstore' => { "options" => { "blobstore_path" => 
      "/var/vcap/micro_bosh/data/cache",
      "path" => "/var/vcap/micro_bosh/data/cache" },
      "provider" => "local" }
     }
  }
end

RSpec.configure do |c|
    c.include Kernel
end

RSpec.configure do |config|
  config.before(:each) do 
    logger = Logger.new(nil)
    allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
  end
end

class LifecycleHelper
  def self.getconfig(default=:none)
    env_file = ENV['LIFECYCLE_ENV_FILE']
    value = if env_file
      load_config_from_file(env_file)
    else
      raise 'Set value of environment variable LIFECYCLE_ENV_FILE'
    end
    value_empty = value.to_s.empty?
    if value_empty && default == :none
      raise("Use LIFECYCLE_ENV_FILE=config.yml or set in ENV")
    end
    value_empty ? default : value
  end

  def self.load_config_from_file(env_file)
    @configs ||= YAML.load_file(env_file)
  rescue => e
    raise e
  end
end
