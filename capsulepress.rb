#!/usr/bin/env ruby

require 'bundler/setup'
require 'dotenv/load'
require './lib/wp'
require './lib/convert'
require './lib/gemini_server'
require './lib/spartan_server'
require './lib/gopher_server'
require 'pathname'
require 'erubis'
require 'marcel'

class CapsulePress
  PAGES_DIR = 'pages'
  TEMPLATES_DIR = 'templates'
  POSTS_PREFIX = '/posts/'
  PREVIEW_PREFIX = "/_preview_/#{ENV['PREVIEW_SECRET']}/"

  def self.known_slugs
    WP.posts(columns: ['wp_posts.post_name'], limit: 99999) .to_a.map{|p|p['post_name']}
  end

  def self.candidate_pages(root, path, protocol)
    path = "#{path}index" if path =~ %r{\/$}
    pages_root = Pathname(File.join(File.dirname(__FILE__), root))
    [
      path,
      "#{path}.#{protocol}.erb",
      "#{path}.erb",
    ].map{|p| File.join(pages_root, p)}.select do |p|
      File.exist?(p) && Pathname(p).realpath.to_s.start_with?(pages_root.realpath.to_s)
    end
  end

  def self.preview(id, protocol)
    return false unless requested_post = WP.preview(id)
    puts "Found preview ##{requested_post['ID']}"
    return false unless template = candidate_pages(TEMPLATES_DIR, 'post', protocol).first
    puts "Using template #{template}"
    { type: 'text/gemini', body: Erubis::Eruby.new(File.read(template)).result(binding) }
  end

  def self.post(slug, protocol)
    safe_slug = slug.gsub(/[^a-z0-9\-]/i, '')
    return false unless requested_post = WP.posts(where: [sprintf("wp_posts.post_name = '%s'", safe_slug)], limit: 1)[0]
    puts "Found post ##{requested_post['ID']}"
    return false unless template = candidate_pages(TEMPLATES_DIR, 'post', protocol).first
    puts "Using template #{template}"
    { type: 'text/gemini', body: Erubis::Eruby.new(File.read(template)).result(binding) }
  end

  def self.handle(path, protocol)
    puts "Requested: #{path}"
    return post(path[POSTS_PREFIX.length..-1], protocol) if path.start_with?(POSTS_PREFIX)
    return preview(path[PREVIEW_PREFIX.length..-1], protocol) if ENV['PREVIEW_SECRET'] && path.start_with?(PREVIEW_PREFIX)
    if page = candidate_pages(PAGES_DIR, path, protocol).first
      # Try to find a candidate page
      mime_type = 'text/gemini'
      page_contents = File.read(page)
      page_contents = Erubis::Eruby.new(page_contents).evaluate({ protocol: protocol }) if page.end_with?('.erb')
      # find any !!! [ruby code] blocks at the beginning of the output and eval them (eek!) to e.g. change mime type
      while page_contents =~ /\A!!! (.*)/
        page_contents = page_contents.split("\n")[1..-1].join("\n") # remove first line
        eval($1) # execute
      end
      return { type: mime_type, body: page_contents }
    else
      # Failing that, try to find a file on the filesystem
      fullpath = Pathname.new(File.join(ENV['WP_CONTENT_UPLOADS_DIR'], path))
      if fullpath.realpath.to_s.start_with?(ENV['WP_CONTENT_UPLOADS_DIR']) && fullpath.exist?
        mime_type = Marcel::MimeType.for(fullpath)
        puts "From filesystem: #{fullpath} (#{mime_type})"
        return { type: mime_type, body: File.read(fullpath) }
      end
    end
    false # failed to handle
  end
end

servers = []

# Launch Gemini capsule
if (!ENV.include?('USE_GEMINI')) || ENV['USE_GEMINI'].downcase == 'true'
  puts "Launching Gemini capsule..."
  gemini_server_wrapper = GeminiServerWrapper.new
  servers << gemini_server_wrapper
end

# Muster Spartan army
if (!ENV.include?('USE_SPARTAN')) || (ENV['USE_SPARTAN'].downcase == 'true')
  puts "Mustering Spartan army..."
  spartan_server = SpartanServer.new
  spartan_server.audit = true # log output
  # spartan_server.debug = true # debugging
  spartan_server.start
  servers << spartan_server
end

# Dig Gopher hole
if (!ENV.include?('USE_GOPHER')) || (ENV['USE_GOPHER'].downcase == 'true')
  puts "Digging Gopher hole..."
  gopher_server = GopherServer.new
  servers << gopher_server
end

loop do
  if servers.empty?
    puts "No servers are configured. Stopping."
    break
  elsif servers.any?(&:stopped?)
    stopped_server_list = servers.select(&:stopped?).map{|s|"- #{s.class.name}"}.join("\n")
    puts "One or more servers have stopped:\n#{stopped_server_list}"
    break
  end
  sleep 1
end
