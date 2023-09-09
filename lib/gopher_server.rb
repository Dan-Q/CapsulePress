require 'gopher2000'
require 'word_wrap'
require 'word_wrap/core_ext'

class GopherServer
  attr_reader :app, :server

  def self.guess_link_type_for(path)
    return 'g' if path =~ /\.(gif)$/i # image, GIF
    return ':' if path =~ /\.(bmp|dib)$/i # image, generic
    return 'I' if path =~ /\.(webp|jpe?g|png|svg)$/i # image, generic
    return '5' if path =~ /\.(zip|tar|7z)$/i # archive
    return 's' if path =~ /\.(wav|mp3|opus|pcm)$/i # audio
    return ';' if path =~ /\.(mp4|mkv|mov)$/i # video
    return 'd' if path =~ /\.(docx?|xlsx?|pptx?|odt)$/i # document
    return 'P' if path =~ /\.(pdf)$/i # pdf
    '1' # menu
  end

  def self.gopherize_erbout(erbout)
    erbout.each_line.map{|line|
      line = line.gsub(/\n*$/, '')
      if line =~ /^=> (URL:[^\s]+) (.+)$/
        # URL:-link (non-gopher, usually e.g. http/https)
        "h#{$2}\t#{$1}\t(FALSE)\t0"
      elsif line =~ /^=> ([^\s]+) (.+)$/
        # link
        "#{guess_link_type_for($1)}#{$2}\t#{$1}\t#{ENV['GOPHER_DOMAIN']}\t#{ENV['GOPHER_PORT']}"
      elsif line =~ /^=> ([^\s]+)$/
        # anonymous link
        "#{guess_link_type_for($1)}#{$1}\t#{$1}\t#{ENV['GOPHER_DOMAIN']}\t#{ENV['GOPHER_PORT']}"
      else
        # text - first wrap it!
        line.gsub(/\t/,'    ').wrap(79).each_line.map{|part|"i#{part.rstrip}\tnull\t(FALSE)\t0"}.join("\n")
      end
    }.join("\n")
  end

  def initialize
    @thread = Thread.new do
      @app = Gopher::Application.new
      @app.reset!
      @app.config[:host] = ENV['GOPHER_HOST'] || '0.0.0.0'
      @app.config[:port] = ENV['GOPHER_PORT'] || 70
      @app.default_route do
        # puts @request.inspect # selector MIGHT not have a preceeding /, add one if not!
        if response = CapsulePress.handle(@request.selector, 'gopher') || CapsulePress.handle('_not_found', 'gopher')
          body = (response[:type] == 'text/gemini') ? GopherServer.gopherize_erbout(response[:body]) : response[:body]
          body
        end
      end

      @server = Gopher::Server.new(@app)
      @server.run!
    end
  end

  def stopped?
    !@thread.status
  end
end

