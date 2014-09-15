require 'capybara/poltergeist'
require 'csv'
require 'highline/import'
require 'open-uri'
require 'ostruct'
require 'optparse'

require_relative '../access_checker'
module AccessChecker

  # A command line interface for checking access on URL:s read from a CSV file
  class CLI

    # Wraps a Capybara session and asserts that visited URL:s are guided through
    # the proxy login
    class ProxySession < SimpleDelegator
      alias_method :session, :__getobj__

      # Create a new proxy session, wrapping +session+ and using +user+ and
      # +password+ for authentication.
      def initialize(session, user, password)
        super(session)
        @user, @password = user, password
      end

      # Delegates to the wrapped session, but attempts to login to the proxy if
      # the session is stuck on the proxy login page.
      def visit(*args)
        result = session.visit(*args)
        result = login_to_proxy if on_proxy_login?
        return result
      end

      private

      # Check if the session is stuck on the proxy login page.
      def on_proxy_login?
        session.current_path == "/login" && session.current_url.match(/[?&]qurl=/)
      end

      # Logs in to the proxy
      def login_to_proxy
        session.fill_in('user', :with => @user)
        session.fill_in('pass', :with => @password)
        result = session.find("input[type=submit]").click
        raise "Couldn't log in through proxy" if on_proxy_login?
        return result
      end

    end

    # Returns the options set for this run
    attr_reader :options

    # Accepts an array of command line options and parameters. The array will be
    # cleared from all processed options. Should normally be called with ARGV
    def initialize(args)
      @options = OpenStruct.new
      options_parser.parse!(args)

      if options.include_dir
        Dir[File.join(options.include_dir, "*.rb")].each { |f| load f }
      end

      puts(provider_list) && exit if options.list_providers
      abort "You must supply a provider key" unless options.provider
      abort "#{options.provider} is not a valid provider" unless Checkers.by_key[options.provider]
    end

    # Runs the checking on data in input IO stream. The default script calls
    # this with ARGF after initializing with ARGV has cleared away all options.
    def run(input)
      checker = get_checker_for_provider
      session = Capybara::Session.new(:poltergeist)

      session = proxy_session(session) if options.proxy

      redirect_stdout_to(options.outfile) do
        filter(input, checker, session)
      end
    rescue StandardError => e
      abort "Aborting due to an error: #{e}"
    rescue Interrupt => e
      abort "Aborted (#{e.inspect})"
    end

    private

    # Returns the class of the provider specified by options.provider
    def get_checker_for_provider
      checker_entry = Checkers.by_key.fetch(options.provider)
      checker_entry.klass
    rescue KeyError => e
      abort "Not a known provider: #{options.provider}. (#{e})"
    end

    def proxy_session(session)
      ProxySession.new(session, options.proxy_user, options.proxy_password)
    end

    # Returns a list of all available providers and their descriptions.
    def provider_list
      checkers = Checkers.by_key
      max_key_length = checkers.keys.map { |key| key.length }.max
      entry_format = "  %-#{max_key_length}s : %s"
      list = []
      list << "Available providers:\n\n"
      list << sprintf(entry_format, "KEY", "DESCRIPTION")
      checkers.keys.sort.each do |key|
        description = checkers[key].description
        list << sprintf(entry_format, key, description)
      end
      list
    end

    # Returns the csv_options to be used, after parsing options
    def csv_options
      csv_options = {:col_sep => ';'}

      if options.headers
        csv_options[:headers]        = true
        csv_options[:return_headers] = true
        csv_options[:write_headers]  = true
      end
      csv_options
    end

    # Loops through input that should be an IO stream containting CSV, and
    # passes each found URL to the checker_session
    #
    # Prints the same CSV with two extra columns for the checking result
    def filter(input, checker_class, session)
      input.lineno = 0
      CSV.filter(input, csv_options) do |row|
        if row.is_a? CSV::Row
          if options.url_header
            url = row.fetch(options.url_header) {
              abort "Header '#{options.url_header}' not found"
            }
          else
            url ||= row["url"] || row["URL"] || row["link"]
          end
          if row.header_row?
            row << { "result"  => "result"  }
            row << { "message"  => "message"  }
            next
          end
        end
        url ||= row[- 1]
        result = checker_class.new(session, url).result
        row << result.name
        row << result.message
      end
    rescue StandardError => e
      abort "Error when processing line #{input.lineno}: #{e.inspect}"
    end

    # Redirects $stdout to +file+, and set it to sync during the execution the
    # supplied block.
    #
    # If file is nil or false, no redirection happens, but sync is set.
    #
    # When the block returns, $stdoyt is reset to it's original value, including
    # the sync setting.
    def redirect_stdout_to(file)
      previous_stdout = $stdout.clone
      $stdout.reopen(file, "w") if file
      $stdout.sync = true
      yield
    ensure
      $stdout.close unless $stdout.closed? || $stdout === previous_stdout
      $stdout = previous_stdout
    end


    # Utility method to fix OptionParsers inability to wrap parameter
    # descriptions in a nice way.
    #
    # Word wraps supplied str to the specified width. Also strips any repeated
    # whitespace, so strings might be written over multiple lines. To make line
    # breaks in the description, separate strings must be used.
    def wrap(str, width=42)
      str.gsub(/(\s)+/, '\1').scan(/\S.{0,#{width}}\S(?=\s|$)|\S+/)
    end


    # Defines the options for the CLI
    def options_parser
      @options_parser ||= OptionParser.new do |o|
        o.banner = "Usage:\n    access_checker -p PROVIDER [options] [FILE [FILE [...]]"
        o.separator "    access_checker -l"


        o.separator ""
        o.separator "Required parameter:"

        o.on( "-p", "--provider KEY", "Process URL:s from this provider."
        ) { |v| options.provider = v }

        o.on( "-l", "--list-providers", %q[Show keys for available providers.]
        ) { options.list_providers = true }

        o.separator ""
        o.separator "Options:"

        o.on( "-H", "--headers",
          %[The input contains a header row.],
          *wrap(%q[If a header is named 'url', 'URL' or 'link' (checked in that
                   order), URL:s will be read from that column.]),
        ){ options.headers = true }

        o.on( "-I", "--include DIR",
          *wrap(%q[Load all Ruby files in DIR. Use this to use your own checker
                 without modifying the script.]),
          *wrap(%q[If the custom checker are already on the load path, simply
                   put a *.rb file in DIR with a require statement:]),
          " ",
          "    require 'path/to/checker'"
        ){ |v| options.include_dir = v }

        o.separator ""
        o.on(
          "-O",
          "--outfile OUTFILE",
          *wrap(%q[ Use OUTFILE for output. (Defaults is STDOUT.) ])
        ) { |v| options.outfile = v }

        o.on( "-U", "--url-header HEADER",
          *wrap(%q[Read URL:s from the column specified by HEADER. (Implies `-h`.)])
        ){ |v| options.url_header = v; options.headers = true; }

        o.on( "-x", "--proxy",
          *wrap(%q[Login through EZproxy before checking.]),
          *wrap(%q[Requires environment variables EZPROXY_USER and EZPROXY_PASSWORD to be set.])
        ) do
          options.proxy          = true
          policy = Proc.new { |key|
            abort "When using --proxy you must set the environment variable #{key}"
          }
          options.proxy_user     = ENV.fetch("EZPROXY_USER", &policy)
          options.proxy_password = ENV.fetch("EZPROXY_PASSWORD", &policy)
        end

        o.separator ""

        o.separator "Common options:"
        o.on("-h", "--help", "Show this message") { puts o.help; exit }

        o.on("--version", "Show version") do
          puts AccessChecker::Version.join('.')
          exit
        end

        o.separator ""
        o.separator "Description:"
        o.separator "    Checks if URL:s in FILE or STDIN leads to an accessible full text."
        o.separator "    Expects input to be in CSV format with URL:s in the last column."
        o.separator ""
        o.separator "    Output is the same CSV with the columns 'result' and 'message' added."

      end
    end

  end
end
