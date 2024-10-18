require 'gserver'
require 'word_wrap'
require 'word_wrap/core_ext'

class NexServer < GServer
  def initialize
    super(
      (ENV['NEX_PORT'] ? ENV['NEX_PORT'].to_i                           : 1900),
      (ENV['NEX_HOST']                                                 || '0.0.0.0'),
      (ENV['NEX_MAX_CONNECTIONS'] ? ENV['NEX_MAX_CONNECTIONS'].to_i : 4)
    )
  end

  def handle(io, req)
    puts "Nex: handling"
    io.print "\r\n"
    req = '/' if req == ''
    if response = CapsulePress.handle(req, 'nex')
      io.print response[:body].wrap(79)
    else
      io.print "Document not found\r\n"
    end
  end

  def serve(io)
    puts "Nex: client connected"
    req = io.gets.strip
    handle(io, req)
  end
end

