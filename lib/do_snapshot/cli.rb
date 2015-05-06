# -*- encoding : utf-8 -*-
require 'thor'
require 'do_snapshot'
require_relative 'command'
require_relative 'mail'
require_relative 'log'

module DoSnapshot
  # CLI is here
  #
  class CLI < Thor # rubocop:disable ClassLength
    default_task :snap

    map %w( c s create )  => :snap
    map %w( -V ) => :version

    # Overriding Thor method for custom initialization
    #
    def initialize(*args)
      super

      set_logger
      set_mailer

      # Check for keys via options
      %w( digital_ocean_client_id digital_ocean_api_key digital_ocean_access_token ).each do |key|
        ENV[key.upcase] = options[key] if options.include? key
      end
    end

    desc 'c / s / snap / create', 'DEFAULT. Create and cleanup snapshot\'s'
    long_desc <<-LONGDESC
    `do_snapshot` able to create and cleanup snapshots on your droplets.

    You can optionally specify parameters to select or exclude some droplets.

    ### Examples

    Select api version (1, 2):

    $ do_snapshot -a 2

    Set DigitalOcean keys:

    $ do_snapshot --digital_ocean_api_token SOMELONGTOKEN

    Keep latest 5 and cleanup older if maximum is reached, verbose:

    $ do_snapshot -k 5 -c -v

    Keep latest 3 from selected droplet:

    $ do_snapshot --only 123456 --keep 3

    Working with all except selected droplets:

    $ do_snapshot --exclude 123456 123457

    Keep latest 5 snapshots, not create new if we have more, send mail notification instead:

    $ do_snapshot --keep 10 --stop --mail to:yourmail@example.com

    ### Cron example

    0 4 * * 7 /.../bin/do_snapshot -k 5 -m to:TO from:FROM -t address:HOST user_name:LOGIN password:PASSWORD port:2525 -q -c

    ### Advanced options example for MAIL feature:

    --mail to:mail@somehost.com from:from@host.com --smtp address:smtp.gmail.com port:25 user_name:someuser password:somepassword

    For more details look here: https://github.com/benprew/pony

    VERSION: #{DoSnapshot::VERSION}
    LONGDESC
    method_option :protocol,
                  type: :numeric,
                  default: 1,
                  aliases: %w( -p ),
                  banner: '1',
                  desc: 'Select api version.'
    method_option :only,
                  type: :array,
                  default: [],
                  aliases: %w( -o ),
                  banner: '123456 123456 123456',
                  desc: 'Select some droplets.'
    method_option :exclude,
                  type: :array,
                  default: [],
                  aliases: %w( -e ),
                  banner: '123456 123456 123456',
                  desc: 'Except some droplets.'
    method_option :keep,
                  type: :numeric,
                  default: 10,
                  aliases: %w( -k ),
                  banner: '5',
                  desc: 'How much snapshots you want to keep?'
    method_option :delay,
                  type: :numeric,
                  default: 10,
                  aliases: %w( -d ),
                  banner: '5',
                  desc: 'Delay between snapshot operation status requests.'
    method_option :timeout,
                  type: :numeric,
                  default: 3600,
                  banner: '250',
                  desc: 'Timeout in sec\'s for events like Power Off or Create Snapshot.'
    method_option :mail,
                  type: :hash,
                  aliases: %w( -m ),
                  banner: 'to:yourmail@example.com',
                  desc: 'Receive mail if fail or maximum is reached.'
    method_option :smtp,
                  type: :hash,
                  aliases: %w( -t ),
                  banner: 'user_name:yourmail@example.com password:password',
                  desc: 'SMTP options.'
    method_option :log,
                  type: :string,
                  aliases: %w( -l ),
                  banner: '/Users/someone/.do_snapshot/main.log',
                  desc: 'Log file path. By default logging is disabled.'
    method_option :clean,
                  default: true,
                  type: :boolean,
                  aliases: %w( -c ),
                  desc: 'Cleanup snapshots after create. If you have more images than you want to `keep`, older will be deleted.'
    method_option :stop,
                  type: :boolean,
                  aliases: %w( -s),
                  desc: 'Stop creating snapshots if maximum is reached.'
    method_option :trace,
                  type: :boolean,
                  aliases: %w( -v ),
                  desc: 'Verbose mode.'
    method_option :quiet,
                  type: :boolean,
                  aliases: %w( -q ),
                  desc: 'Quiet mode. If don\'t need any messages and in console.'

    method_option :digital_ocean_access_token,
                  type: :string,
                  banner: 'YOURLONGAPITOKEN',
                  desc: 'DIGITAL_OCEAN_ACCESS_TOKEN. if you can\'t use environment.'
    method_option :digital_ocean_client_id,
                  type: :string,
                  banner: 'YOURLONGAPICLIENTID',
                  desc: 'DIGITAL_OCEAN_CLIENT_ID. if you can\'t use environment.'
    method_option :digital_ocean_api_key,
                  type: :string,
                  banner: 'YOURLONGAPIKEY',
                  desc: 'DIGITAL_OCEAN_API_KEY. if you can\'t use environment.'

    def snap
      Command.load_options options, %w( log mail smtp trace digital_ocean_client_id digital_ocean_api_key digital_ocean_access_token )
      Command.snap
    rescue => e
      Command.fail_power_off(e) if [SnapshotCreateError, DropletShutdownError].include?(e.class)
      Log.error e.message
      backtrace(e) if options.include? 'trace'
      send_error
    end

    desc 'version, -V', 'Shows the version of the currently installed DoSnapshot gem'
    def version
      puts DoSnapshot::VERSION
    end

    no_commands do
      def set_mailer
        Mail.opts = options['mail']
        Mail.smtp = options['smtp']
      end

      def send_error
        return unless Mail.opts

        Mail.opts[:subject] = 'Digital Ocean: Error.'
        Mail.opts[:body] = 'Please check your droplets.'
        Mail.notify
      end

      def set_logger
        Log.quiet = options['quiet']
        Log.verbose = options['trace']
        # Use Thor shell
        Log.shell = shell unless options['quiet']
        init_logger if options.include?('log')
      end

      def init_logger
        Log.logger = Logger.new(options['log'])
        Log.logger.level = Log.verbose ? Logger::DEBUG : Logger::INFO
      end

      def backtrace(e)
        e.backtrace.each do |t|
          Log.error t
        end
      end
    end
  end
end