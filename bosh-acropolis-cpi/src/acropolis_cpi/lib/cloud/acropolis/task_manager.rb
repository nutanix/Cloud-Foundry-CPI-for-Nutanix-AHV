require 'json'

module Bosh
  module AcropolisCloud
    class TaskManager
      include Helpers

      # Checks the status of a specified task
      #
      # @param [String] task_uuid Uuid of the task
      # @param [NutanixRestClient] client Instance of the rest client
      # @param [Bosh::Cloud::Config.logger] logger Instance of logger
      # @param [Number] timeout Default set to 300 seconds
      # @return [String] Uuid of the entity returned by the task
      def self.wait_on_task(task_uuid, client, logger, timeout = 300)
        # Build payload for tasks/poll
        spec = { completed_tasks: [task_uuid], timeout_interval: timeout }
        # Make the REST call and get task information
        task = JSON.parse(client.post('v2.0', 'tasks/poll', spec.to_json))
        logger.debug("Task details => #{task}")
        # Check whether the task is successful
        if task['completed_tasks_info'].first['progress_status'] != 'Succeeded'
          error_code = task['completed_tasks_info'].first['meta_response']['error_code']
          error_detail = task['completed_tasks_info'].first['meta_response']['error_detail']
          operation_type = task['completed_tasks_info'].first['operation_type']
          error_message = "Operation #{operation_type} failed." \
                          " Error Code #{error_code}: #{error_detail}."
          logger.error(error_message)
          raise error_message
        end
        # Return the uuid of the subject entity for the task
        task['completed_tasks_info'].first['entity_list'].first['entity_id']
      rescue => e
        raise e
      end
    end
  end
end
