require 'buff/ruby_engine'

module Ridley
  class ConnectorSupervisor < ::Celluloid::SupervisionGroup
    include Ridley::Logging

    # @param [Celluloid::Registry] registry
    def initialize(registry, connector_pool_size)
      super(registry)

      if connector_pool_size > 1
        log.info { "Host ConnectorSupervisor pool starting with size: #{connector_pool_size}" }
        pool(HostConnector::SSH, size: connector_pool_size, as: :ssh)
        pool(HostConnector::WinRM, size: connector_pool_size, as: :winrm)
      else
        supervise_as :ssh, HostConnector::SSH
        supervise_as :winrm, HostConnector::WinRM
      end
    end
  end

  class HostCommander
    include Celluloid
    include Ridley::Logging

    DEFAULT_WINDOWS_CONNECTOR = "winrm"
    DEFAULT_LINUX_CONNECTOR = "ssh"

    VALID_CONNECTORS = [ DEFAULT_WINDOWS_CONNECTOR, DEFAULT_LINUX_CONNECTOR ]

    finalizer :finalize_callback

    def initialize(connector_pool_size=nil)
      connector_pool_size ||= 1
      @connector_registry   = Celluloid::Registry.new
      @connector_supervisor = ConnectorSupervisor.new_link(@connector_registry, connector_pool_size)
    end

    # Execute a shell command on a node
    #
    # @param [String] host
    #   the host to perform the action on
    # @param [String] command
    #
    # @option options [Hash] :ssh
    #   * :user (String) a shell user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the shell user that will perform the bootstrap
    #   * :keys (Array, String) an array of key(s) to authenticate the ssh user with instead of a password
    #   * :timeout (Float) timeout value for SSH bootstrap (5.0)
    #   * :sudo (Boolean) run as sudo
    # @option options [Hash] :winrm
    #   * :user (String) a user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the user that will perform the bootstrap (required)
    #   * :port (Fixnum) the winrm port to connect on the node the bootstrap will be performed on (5985)
    # @option options [String] :connector
    #   a connector type to prefer
    #
    # @return [HostConnector::Response]
    def run(host, command, options = {})
      execute(__method__, host, command, options)
    end

    # Bootstrap a node
    #
    # @param [String] host
    #   the host to perform the action on
    #
    # @option options [Hash] :ssh
    #   * :user (String) a shell user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the shell user that will perform the bootstrap
    #   * :keys (Array, String) an array of key(s) to authenticate the ssh user with instead of a password
    #   * :timeout (Float) timeout value for SSH bootstrap (5.0)
    #   * :sudo (Boolean) run as sudo
    # @option options [Hash] :winrm
    #   * :user (String) a user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the user that will perform the bootstrap (required)
    #   * :port (Fixnum) the winrm port to connect on the node the bootstrap will be performed on (5985)
    #
    # @return [HostConnector::Response]
    def bootstrap(host, options = {})
      execute(__method__, host, options)
    end

    # Perform a chef client run on a node
    #
    # @param [String] host
    #   the host to perform the action on
    #
    # @option options [Hash] :ssh
    #   * :user (String) a shell user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the shell user that will perform the bootstrap
    #   * :keys (Array, String) an array of key(s) to authenticate the ssh user with instead of a password
    #   * :timeout (Float) timeout value for SSH bootstrap (5.0)
    #   * :sudo (Boolean) run as sudo
    # @option options [Hash] :winrm
    #   * :user (String) a user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the user that will perform the bootstrap (required)
    #   * :port (Fixnum) the winrm port to connect on the node the bootstrap will be performed on (5985)
    # @option options [String] :connector
    #   a connector type to prefer
    #
    # @return [HostConnector::Response]
    def chef_client(host, options = {})
      execute(__method__, host, options)
    end

    # Write your encrypted data bag secret on a node
    #
    # @param [String] host
    #   the host to perform the action on
    # @param [String] secret
    #   your organization's encrypted data bag secret
    #
    # @option options [Hash] :ssh
    #   * :user (String) a shell user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the shell user that will perform the bootstrap
    #   * :keys (Array, String) an array of key(s) to authenticate the ssh user with instead of a password
    #   * :timeout (Float) timeout value for SSH bootstrap (5.0)
    #   * :sudo (Boolean) run as sudo
    # @option options [Hash] :winrm
    #   * :user (String) a user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the user that will perform the bootstrap (required)
    #   * :port (Fixnum) the winrm port to connect on the node the bootstrap will be performed on (5985)
    # @option options [String] :connector
    #   a connector type to prefer
    #
    # @return [HostConnector::Response]
    def put_secret(host, secret, options = {})
      execute(__method__, host, secret, options)
    end

    # Execute line(s) of Ruby code on a node using Chef's embedded Ruby
    #
    # @param [String] host
    #   the host to perform the action on
    # @param [Array<String>] command_lines
    #   An Array of lines of the command to be executed
    #
    # @option options [Hash] :ssh
    #   * :user (String) a shell user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the shell user that will perform the bootstrap
    #   * :keys (Array, String) an array of key(s) to authenticate the ssh user with instead of a password
    #   * :timeout (Float) timeout value for SSH bootstrap (5.0)
    #   * :sudo (Boolean) run as sudo
    # @option options [Hash] :winrm
    #   * :user (String) a user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the user that will perform the bootstrap (required)
    #   * :port (Fixnum) the winrm port to connect on the node the bootstrap will be performed on (5985)
    # @option options [String] :connector
    #   a connector type to prefer
    #
    # @return [HostConnector::Response]
    def ruby_script(host, command_lines, options = {})
      execute(__method__, host, command_lines, options)
    end

    # Uninstall Chef from a node
    #
    # @param [String] host
    #   the host to perform the action on
    #
    # @option options [Boolena] :skip_chef (false)
    #   skip removal of the Chef package and the contents of the installation
    #   directory. Setting this to true will only remove any data and configurations
    #   generated by running Chef client.
    # @option options [Hash] :ssh
    #   * :user (String) a shell user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the shell user that will perform the bootstrap
    #   * :keys (Array, String) an array of key(s) to authenticate the ssh user with instead of a password
    #   * :timeout (Float) timeout value for SSH bootstrap (5.0)
    #   * :sudo (Boolean) run as sudo (true)
    # @option options [Hash] :winrm
    #   * :user (String) a user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the user that will perform the bootstrap (required)
    #   * :port (Fixnum) the winrm port to connect on the node the bootstrap will be performed on (5985)
    # @option options [String] :connector
    #   a connector type to prefer
    #
    # @return [HostConnector::Response]
    def uninstall_chef(host, options = {})
      execute(__method__, host, options)
    end

    # Update a node's Omnibus installation of Chef
    #
    # @param [String] host
    #   the host to perform the action on
    #
    # @option options [String] :chef_version
    #   the version of Chef to install on the node
    # @option options [Boolean] :prerelease
    #   install a prerelease version of Chef
    # @option options [String] :direct_url
    #   a url pointing directly to a Chef package to install
    # @option options [Hash] :ssh
    #   * :user (String) a shell user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the shell user that will perform the bootstrap
    #   * :keys (Array, String) an array of key(s) to authenticate the ssh user with instead of a password
    #   * :timeout (Float) timeout value for SSH bootstrap (5.0)
    #   * :sudo (Boolean) run as sudo (true)
    # @option options [Hash] :winrm
    #   * :user (String) a user that will login to each node and perform the bootstrap command on
    #   * :password (String) the password for the user that will perform the bootstrap (required)
    #   * :port (Fixnum) the winrm port to connect on the node the bootstrap will be performed on (5985)
    #
    # @return [HostConnector::Response]
    def update_omnibus(host, options = {})
      execute(__method__, host, options)
    end

    # Finds and returns the best HostConnector for a given host
    #
    # @param [String] host
    #   the host to attempt to connect to
    # @option options [Hash] :ssh
    #   * :port (Fixnum) the ssh port to connect on the node the bootstrap will be performed on (22)
    #   * :timeout (Float) [5.0] timeout value for testing SSH connection
    #   * :gateway (String) user@host:port
    # @option options [Hash] :winrm
    #   * :port (Fixnum) the winrm port to connect on the node the bootstrap will be performed on (5985)
    # @option options [String] :connector
    #   a connector type to prefer
    # @param block [Proc]
    #   an optional block that is yielded the best HostConnector
    #
    # @return [HostConnector::SSH, HostConnector::WinRM, NilClass]
    def connector_for(host, options = {})
      connector = options[:connector]

      if !VALID_CONNECTORS.include?(connector)
        log.warn { "Received connector '#{connector}' is not one of #{VALID_CONNECTORS}. Checking default connectors..." }
        connector = nil
      end

      if (connector == DEFAULT_WINDOWS_CONNECTOR || connector.nil?) && 
          winrm.connector_port_open?(host, options)
        options.delete(:ssh)
        winrm
      elsif (connector == DEFAULT_LINUX_CONNECTOR || connector.nil?) && 
          ssh.connector_port_open?(host, options)
        options.delete(:winrm)
        ssh
      else
        nil
      end
    end

    private

      # A helper method for sending the provided method to a proper
      # connector actor.
      #
      # @param [Symbol] method
      #   the method to call on the connector actor
      # @param [String] host
      #   the host to connect to
      # @param [Array] args
      #   the splatted args passed to the method
      #
      # @return [HostConnector::Response]
      def execute(method, host, *args)
        options = args.last.is_a?(Hash) ? args.pop : Hash.new

        connector = connector_for(host, options)
        if connector.nil?
          log.warn { "No connector ports open on '#{host}'" }
          HostConnector::Response.new(host, stderr: "No connector ports open on '#{host}'")
        else
          connector.send(method, host, *args, options)
        end
      end

      def finalize_callback
        @connector_supervisor.async.terminate if @connector_supervisor && @connector_supervisor.alive?
      end

      def ssh
        @connector_registry[:ssh]
      end

      def winrm
        @connector_registry[:winrm]
      end
  end
end
