require 'spec_helper'
require 'cloud/acropolis/helpers'
require 'kernel'

RSpec.configure do |c|
  c.include Bosh::AcropolisCloud::Helpers
end

describe 'cloud_error' do
  it 'raises error' do
    expect { cloud_error('message') }
      .to raise_error(Bosh::Clouds::CloudError)
  end
end

describe 'unpack_image' do
  let(:result) { instance_double('Bosh::Exec::Result') }
  before do
    allow_message_expectations_on_nil

    allow(@logger).to receive(:error)
      .with('Extracting stemcell root image failed in dir' \
            ' tmp_dir, tar returned 1, output: output')
    allow(result).to receive(:output)
      .and_return('output')

    allow(result).to receive(:exit_status)
      .and_return(1)

    allow(Bosh::Exec).to receive(:sh)
      .with('tar -C tmp_dir -xzf img_path 2>&1', on_error: :return)
      .and_return(result)
  end
  context 'when tar command executes successfully' do
    it 'unpacks the image' do
      allow(result).to receive(:failed?)
        .and_return(false)

      allow(File).to receive(:join)
        .with('tmp_dir', 'root.img')
        .and_return('root_image')

      allow(File).to receive(:exist?)
        .with('root_image')
        .and_return(true)

      expect(unpack_image('tmp_dir', 'img_path'))
        .to eq('root_image')
    end
  end
  context 'when tar command gives error' do
    it 'does not unpack the image' do
      allow(result).to receive(:failed?)
        .and_return(true)

      expect { unpack_image('tmp_dir', 'img_path') }
        .to raise_error(Bosh::Clouds::CloudError)
    end
  end
  context 'when root.img does not exist in archive' do
    it 'raises error' do
      allow(result).to receive(:failed?)
        .and_return(false)

      allow(File).to receive(:join)
        .with('tmp_dir', 'root.img')
        .and_return('root_image')

      allow(File).to receive(:exist?)
        .with('root_image')
        .and_return(false)

      expect { unpack_image('tmp_dir', 'img_path') }
        .to raise_error(Bosh::Clouds::CloudError)
    end
  end
end

describe '#generate_env_iso' do
  let(:f) { instance_double('file like object') }
  before do
    allow_message_expectations_on_nil

    allow(ENV).to receive(:[])
      .with('PATH')
      .and_return('path')

    allow(File).to receive(:join)
      .with('path', 'genisoimage')
      .and_return('ls')

    allow(File).to receive(:exist?)
      .with('ls')
      .and_return(true)

    allow(Kernel).to receive(:`)
      .with("'pathtobin' -o 'iso_path' 'env_path' 2>&1")

    allow(described_class).to receive(:`)
      .with("'pathtobin' -o 'iso_path' 'env_path' 2>&1")

    allow(File).to receive(:join)
      .with('tmp_path', 'env')
      .and_return('env_path')

    allow(File).to receive(:join)
      .with('tmp_path', 'env.iso')
      .and_return('iso_path')

    allow(File).to receive(:open)
      .with('env_path', 'w')
      .and_return(f)

    allow(f).to receive(:write)
      .with('env'.to_json)
      .and_return(f)

    allow(File).to receive(:open)
      .with('iso_path', 'r')
      .and_return(f)

    allow(f).to receive(:read)
      .and_return(f)
  end
  context 'when exitstatus is 0' do
    it 'generates env.iso' do
      allow($CHILD_STATUS).to receive(:exitstatus)
        .and_return(0)

      expect(generate_env_iso('tmp_path', 'env'))
        .to eq('iso_path')
    end
  end
  context 'when exitstatus is 1' do
    it 'raises an error' do
      allow($CHILD_STATUS).to receive(:exitstatus)
        .and_return(1)

      expect { generate_env_iso('tmp_path', 'env') }
        .to raise_error(RuntimeError)
    end
  end
end

describe '#genisoimage' do
  before do
    allow_message_expectations_on_nil

    allow(ENV).to receive(:[])
      .with('PATH')
      .and_return('path')

    allow(File).to receive(:join)
      .with('path', 'genisoimage')
      .and_return('pathtobin')
  end
  it 'returns location of genisoimage executable' do
    allow(File).to receive(:exist?)
      .with('pathtobin')
      .and_return(true)

    expect(genisoimage)
      .to eq('pathtobin')
  end
  it 'returns location of mkisofs executable' do
    allow(File).to receive(:exist?)
      .with('pathtobin')
      .and_return(false)

    allow(File).to receive(:join)
      .with('path', 'mkisofs')
      .and_return('pathtobin1')

    allow(File).to receive(:exist?)
      .with('pathtobin1')
      .and_return(true)

    expect(genisoimage)
      .to eq('pathtobin1')
  end
  it 'returns "genisoimage" if above two conditions fail' do
    allow(File).to receive(:exist?)
      .with('pathtobin')
      .and_return(false)

    allow(File).to receive(:join)
      .with('path', 'mkisofs')
      .and_return('pathtobin1')

    allow(File).to receive(:exist?)
      .with('pathtobin1')
      .and_return(false)

    expect(genisoimage)
      .to eq('genisoimage')
  end
end

describe '#which' do
  before do
    allow(ENV).to receive(:[])
      .with('PATH')
      .and_return('path')

    allow(File).to receive(:join)
      .with('path', 'genisoimage')
      .and_return('pathtobin')
  end
  context 'when genisoimage pre mastering program is present' do
    it 'checks if file exists in environment path' do
      allow(File).to receive(:exist?)
        .with('pathtobin')
        .and_return(true)

      expect(which(%w(genisoimage mkisofs)))
        .to eq('pathtobin')
    end
  end
  context 'when mkisofs pre mastering program is present' do
    it 'checks if file exists in environment path' do
      allow(File).to receive(:exist?)
        .with('pathtobin')
        .and_return(false)

      allow(File).to receive(:join)
        .with('path', 'mkisofs')
        .and_return('pathtobin1')

      allow(File).to receive(:exist?)
        .with('pathtobin1')
        .and_return(true)

      expect(which(%w(genisoimage mkisofs)))
        .to eq('pathtobin1')
    end
  end
  context 'when none of the pre mastering programs found in environment path' do
    it 'returns "genisoimage"' do
      allow(File).to receive(:exists?)
        .with('pathtobin')
        .and_return(false)

      allow(File).to receive(:join)
        .with('path', 'mkisofs')
        .and_return('pathtobin1')

      allow(File).to receive(:exists?)
        .with('pathtobin1')
        .and_return(false)

      expect(which(%w(genisoimage mkisofs)))
        .to eq('genisoimage')
    end
  end
end
