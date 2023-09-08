require 'gemini_server'

class GeminiServerWrapper
  attr_reader :gemini_server, :thread

  def initialize
    @gemini_server = GeminiServer.new(
      cert_path:     ENV['GEMINI_CERT_PATH'],
      key_path:      ENV['GEMINI_KEY_PATH'],
      public_folder: ENV['WP_CONTENT_UPLOADS_DIR'],
    )
    @gemini_server.route('**') do
      if response = CapsulePress.handle(params['splat'][1], 'gemini')
        # First, try CapsulePress's handler
        mime_type response[:type]
        success   response[:body]
      else
        not_found
      end
    end
    @thread = Thread.new {
      @gemini_server.listen(
        ENV['GEMINI_HOST'] || '0.0.0.0',
        ENV['GEMINI_PORT'] || 1965
      )
    }
  end

  def stopped?
    !@thread.status
  end
end

