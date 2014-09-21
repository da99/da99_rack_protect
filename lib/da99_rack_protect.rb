
require 'rack/protection'

class Da99_Rack_Protect

  HOSTS             = []
  DA99              = self

  # =================================================================
  #
  # I need to know if new middleware has been added
  # to `rack-protection` so it can be properly
  # used (or ignored) by Da99_Rack_Protect.
  #
  # =================================================================
  RACK_PROTECTS_DIR = File.join File.dirname(`gem which rack-protection`.strip), '/rack/protection'
  RACK_PROTECTS     = Dir.glob(RACK_PROTECTS_DIR + '/*').map { |f|
    File.basename(f).sub('.rb', '') 
  }.sort

  Ignore_Rack_Protects = %w{ base version escaped_params }
  Known_Rack_Protects = %w{
    remote_referrer
    authenticity_token
    form_token
    frame_options
    http_origin
    ip_spoofing
    json_csrf
    path_traversal
    remote_token
    session_hijacking
    xss_header
  }

  Unknown_Rack_Protects = RACK_PROTECTS - Known_Rack_Protects - Ignore_Rack_Protects

  if !Unknown_Rack_Protects.empty?
    fail "Unknown rack-protection middleware: #{Unknown_Rack_Protects.inspect}"
  end
  # =================================================================

  dir   = File.expand_path(File.dirname(__FILE__) + '/da99_rack_protect')
  files = Dir.glob(dir + '/*.rb').sort
  Names = files.map { |file|
    base = File.basename(file).sub('.rb', '')
    require "da99_rack_protect/#{base}"
    pieces = base.split('_')
    pieces.shift
    pieces.join('_').to_sym
  }

  class << self

    def config *args
      yield(self) if block_given?
      case args.length
      when 0
        # do nothing

      when 2

        case args.first

        when :host
          HOSTS.concat args.last

        else
          fail "Unknown args: #{args.inspect}"

        end # === case

      else
        fail "Unknown args: #{args.inspect}"
      end # === case

      self
    end # === def config

    def redirect new, code = 301
      res = Rack::Response.new
      res.redirect new, code
      res.finish
    end

    def response code, type, raw_content
      content = raw_content.to_s
      res = Rack::Response.new
      res.status = code.to_i
      res.headers['Content-Length'] = content.bytesize.to_s
      res.headers['Content-Type']   = 'text/plain'.freeze
      res.body = [content]
      res.finish
    end

  end # === class self

  def initialize main_app
    @app = Rack::Builder.new do

      use Rack::Lint
      use Rack::ContentLength
      use Rack::ContentType, "text/plain"
      use Rack::MethodOverride
      use Rack::Session::Cookie, secret: SecureRandom.urlsafe_base64(nil, true)
      use Rack::Protection

      Names.each { |name|
        use Da99_Rack_Protect.const_get(name)
      }

      if ENV['IS_DEV']
        use Rack::CommonLogger
        use Rack::ShowExceptions
      end

      run main_app
    end
  end

  def call env
    @app.call env
  end

end # === class Da99_Rack_Protect ===