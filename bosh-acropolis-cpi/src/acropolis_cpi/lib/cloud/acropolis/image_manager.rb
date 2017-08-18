require 'common/common'
require 'json'

module Bosh
  module AcropolisCloud
    class NutanixImageManager
      # Constructor
      # @param [NutanixRestClient] client Client instance
      def initialize(client, logger)
        @client = client
        @logger = logger
      end

      # Creates a new image and uploads it
      #
      # @param [String] name Name of the image
      # @param [String] type 'ISO_IMAGE' or 'DISK_IMAGE'
      # @param [String] container_uuid Uuid of the storage container
      # @param [String] url http(s)://, nfs:/// or
      #                     local filesystem path (/tmp/..)
      def create_image(name, type, container_uuid, url)
        @logger.debug("Request for creating image #{name}.")
        if url.start_with?('http', 'nfs')
          create_image_with_url(name, type, container_uuid, url)
        else
          create_image_with_local(name, type, container_uuid, url)
        end
      rescue => e
        raise e
      end

      def get_image(image_uuid)
        image = @client.get('v2.0', "images/#{image_uuid}")
        JSON.parse(image) unless image.nil?
      rescue => e
        raise "Image #{image_uuid} not found."
      end

      # Deletes an image
      #
      # @param [String] image_uuid Uuid of the image to be deleted
      def delete_image(image_uuid)
        @logger.debug("Request for deleting image #{image_uuid}...")
        task = JSON.parse(@client.delete('v2.0', "images/#{image_uuid}"))
        task_uuid = task['task_uuid']
        TaskManager.wait_on_task(task_uuid, @client, @logger)
        @logger.debug("Image #{image_uuid} deleted.")
      rescue => e
        raise e
      end

      # Creates and uploads an image from a url
      def create_image_with_url(name, type, container_uuid, url)
        @logger.debug("Creating image from url #{url}")
        spec = {  name: name, annotation: name, image_type: type,
                  image_import_spec: {
                    storage_container_uuid: container_uuid, url: url
                  } }
        @logger.debug("Image creation specs => #{spec}")
        task = JSON.parse(@client.post('v2.0', 'images', spec.to_json))
        task_uuid = task['task_uuid']
        # Timeout is set to 60 minutes as image upload may take time
        TaskManager.wait_on_task(task_uuid, @client, @logger, 60 * 60)
      rescue => e
        raise e
      end

      # Creates and uploads an image from a file path
      def create_image_with_local(name, type, container_uuid, path)
        @logger.debug("Creating image from file path #{path}")
        container_id = JSON.parse(
          @client.get('v2.0', "storage_containers/#{container_uuid}")
        )['id'].split('::').last
        @logger.debug("Container ID is #{container_id}")
        spec = { name: name, image_type: type, annotation: name }
        @logger.debug("Image creation specs => #{spec}")
        task = JSON.parse(@client.post('v2.0', 'images', spec.to_json))
        task_uuid = task['task_uuid']
        image_uuid = TaskManager.wait_on_task(task_uuid, @client, @logger)
        task = JSON.parse(
          @client.put('v0.8', "images/#{image_uuid}/upload",
                      File.open(path), nil,
                      { 'X-Nutanix-Destination-Container' => container_id })
        )
        task_uuid = task['task_uuid']
        # Timeout is set to 60 minutes as image upload may take time
        TaskManager.wait_on_task(task_uuid, @client, @logger, 60 * 60)
        image_uuid
      rescue => e
        raise e
      end
    end
  end
end
