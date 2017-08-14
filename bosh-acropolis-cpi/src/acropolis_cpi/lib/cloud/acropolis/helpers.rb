module Bosh
  module AcropolisCloud
    module Helpers
      def self.included(base)
        base.extend(Helpers)
      end

      # Raises CloudError exception
      #
      # @param [String] message Message about what went wrong
      # @param [Exception] exception Exception to be logged (optional)
      def cloud_error(message, exception = nil)
        @logger.error(message) if @logger
        @logger.error(exception) if @logger && exception
        raise Bosh::Clouds::CloudError, message
      end

      # Unpacks a stemcell archive
      #
      # @param [String] tmp_dir Temporary directory
      # @param [String] image_path Local filesystem path to a stemcell image
      # @return [void]
      def unpack_image(tmp_dir, image_path)
        # Extract the image .img file into a temporary directory
        result = Bosh::Exec.sh("tar -C #{tmp_dir} -xzf #{image_path} 2>&1",
                               on_error: :return)
        if result.failed?
          @logger.error('Extracting stemcell root image failed in dir' \
                        " #{tmp_dir}, tar returned #{result.exit_status}," \
                        " output: #{result.output}")
          cloud_error('Extracting stemcell root image failed.' \
                      'Check task debug log for details.')
        end
        # Build the absolute path to the image file
        root_image = File.join(tmp_dir, 'root.img')
        unless File.exist?(root_image)
          cloud_error('Root image is missing from stemcell archive')
        end
        # Return the path
        root_image
      end

      # Creates an ISO and returns its path
      #
      # @param [Hash] env ENV information
      # @return [String] Path to the ISO
      def generate_env_iso(tmp_path, env)
        env_path = File.join(tmp_path, 'env')
        iso_path = File.join(tmp_path, 'env.iso')
        File.open(env_path, 'w') { |f| f.write(env.to_json) }
        output = `#{genisoimage} -o #{iso_path} #{env_path} 2>&1`
        raise "#{$?.exitstatus} -#{output}" if $?.exitstatus != 0
        File.open(iso_path, 'r').read
        iso_path
      end

      # Returns location of genisoimage executable
      def genisoimage
        @genisoimage ||= which(%w(genisoimage mkisofs))
      end

      # Simulation of `which` tool
      #
      # @param [Array] programs List of programs
      def which(programs)
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
          programs.each do |bin|
            exe = File.join(path, bin)
            return exe if File.exist?(exe)
          end
        end
        programs.first
      end
    end
  end
end
