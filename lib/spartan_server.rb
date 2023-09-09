require 'gserver'

class SpartanServer < GServer
  def initialize
    super(
      (ENV['SPARTAN_PORT'] ? ENV['SPARTAN_PORT'].to_i                       : 300),
      (ENV['SPARTAN_HOST']                                                 || '0.0.0.0'),
      (ENV['SPARTAN_MAX_CONNECTIONS'] ? ENV['SPARTAN_MAX_CONNECTIONS'].to_i : 4)
    )
  end

  def handle(io, host, path)
    puts "Spartan: handling"
    if response = CapsulePress.handle(path, 'spartan')
      io.print "2 #{response[:type]}\r\n#{response[:body]}"
    else
      io.print "4 \"#{path}\" not found\r\n"
    end
  end

  def serve(io)
    puts "Spartan: client connected"
    req = io.gets
    puts req
    if req =~ /^(\S+)\s+(\S+)\s+(\d+)/
      if 0 != $3.to_i
        io.print "4 This server does not accept requests with a payload/query\r\n"
      else
        handle(io, $1, $2)
      end
    else
      io.print "4 Unrecognised request format\r\n"
    end
  end
end

