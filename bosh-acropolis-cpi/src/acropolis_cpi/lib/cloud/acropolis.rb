module Bosh
  module AcropolisCloud; end
end

require "httpclient"
require 'rest-client'
require "json"
require "pp"
require "set"
require "tmpdir"
require "securerandom"
require "json"

require "common/exec"
require "common/thread_pool"
require "common/thread_formatter"

require "cloud"
require "cloud/acropolis/helpers"
require "cloud/acropolis/cloud"
require "cloud/acropolis/rest_client"
require "cloud/acropolis/container_manager"
require "cloud/acropolis/image_manager"
require "cloud/acropolis/vm_manager"
require "cloud/acropolis/volume_group_manager"
require "cloud/acropolis/task_manager"

module Bosh
  module Clouds
    Acropolis = Bosh::AcropolisCloud::Cloud
  end
end
