module ImageMagickHelpers
  def imagemagick_available?
    command_available?("mogrify") || command_available?("magick")
  end

  private

  def command_available?(command)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |path|
      next false if path.empty?

      command_path = File.join(path, command)
      File.file?(command_path) && File.executable?(command_path)
    end
  end
end

RSpec.configure do |config|
  config.include ImageMagickHelpers
end
