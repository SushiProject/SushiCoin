require "../cli"

module ::Sushi::Interface::SushiM
  class Root < CLI
    @wallet_path : String?
    @wallet_password : String?
    @node : String?
    @is_testnet : Bool = false
    @threads : Int32 = 1

    def sub_actions
      [] of SushiAction
    end

    def option_parser
      OptionParser.new do |parser|
        parser.on("-w WALLET_PATH", "--wallet-path=WALLET_PATH", "wallet json's path") { |wallet_path|
          @wallet_path = wallet_path
        }
        parser.on("-n NODE", "--node=NODE", "Connecting node") { |node|
          @node = node
        }
        parser.on("--testnet", "Set network type as testnet (default is mainnet)") {
          @is_testnet = true
        }
        parser.on("--threads=THREADS", "# of the work threads (default is 1)") { |threads|
          @threads = threads.to_i
        }
        parser.on("-p PASSWORD", "--password=PASSWORD", "Wallet password") { |password|
          @wallet_password = password
        }
      end
    end

    def run_impl(action_name)
      unless wallet_path = @wallet_path
        puts_help(HELP_WALLET_PATH)
      end

      unless wallet_password = @wallet_password
        puts_help(HELP_WALLET_PASSWORD)
      end

      unless node = @node
        puts_help(HELP_CONNECTING_NODE)
      end

      node_uri = URI.parse(node)

      unless host = node_uri.host
        puts_help(HELP_CONNECTING_NODE)
      end

      unless port = node_uri.port
        puts_help(HELP_CONNECTING_NODE)
      end

      encrypted_wallet = Core::Wallet.from_path(wallet_path)
      wallet = Core::Wallet.decrypt(encrypted_wallet, wallet_password)
      wallet_is_testnet = (Core::Wallet.address_network_type(wallet.address)[:name] == "testnet")

      raise "Wallet type mismatch" if @is_testnet != wallet_is_testnet

      miner = Core::Miner.new(@is_testnet, host, port, wallet, @threads)
      miner.run
    end
  end
end

include ::Sushi::Interface
include Sushi::Core::Keys

::Sushi::Interface::SushiM::Root.new(
  {name: "sushim", desc: "Sushi's mining process"}, [] of SushiAction, true
).run
