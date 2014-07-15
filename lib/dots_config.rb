module DotsConfig
  class ConfigParser
    def symlinks
      config['symlinks']
    end

    def erbs
      config['erbs']
    end

    private

    def config
      require 'yaml'
      @config ||= YAML.load raw_config
    end

    def raw_config
      File.read './config/dots_config.yml'
    end
  end

  def config
    ConfigParser.new
  end
end
