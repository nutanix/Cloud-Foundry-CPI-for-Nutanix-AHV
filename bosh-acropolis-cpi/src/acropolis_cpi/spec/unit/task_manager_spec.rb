require 'spec_helper'
require 'cloud/acropolis/task_manager'
require 'cloud/acropolis/cloud'

describe Bosh::AcropolisCloud::TaskManager do
  let(:logger) { Bosh::Clouds::Config.logger }
  let(:client) { instance_double('Bosh::AcropolisCloud::NutanixRestClient') }

  before do
    allow(client).to receive(:post)
      .with(API_VERSION, 'tasks/poll',
            { completed_tasks: ['task_uuid'], timeout_interval: 300 }.to_json)
      .and_return(task_info('Succeeded'))

    allow(client).to receive(:post)
      .with(API_VERSION, 'tasks/poll',
            { completed_tasks: ['task_uuid'], timeout_interval: 101 }.to_json)
      .and_return(task_info('Queued'))
  end

  describe '.wait_on_task' do
    context 'when task succeeds' do
      it 'returns the entity_id' do
        expect(Bosh::AcropolisCloud::TaskManager
                 .wait_on_task('task_uuid', client, logger))
          .to eq('entity_id')
      end
    end

    context 'when task does not succeed' do
      it 'raises error' do
        expect do
          Bosh::AcropolisCloud::TaskManager.wait_on_task('task_uuid',
                                                         client, logger, 101)
        end
          .to raise_error(RuntimeError)
      end
    end
  end
end

def task_info(progress_status)
  '{"completed_tasks_info":
        [{
          "entity_list":
          [{
            "entity_id": "entity_id"
          }],
          "meta_response": {
            "error_code" : 100,
            "error_detail": "error_detail"
          },
          "operation_type": "operation_type",
          "progress_status": "' + progress_status + '" }]
    }'
end
