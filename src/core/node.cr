require "./node/*"

module ::Garnet::Core
  class Node
    @blockchain        : Blockchain
    @id                : String
    @nodes             : Models::Nodes
    @miners            : Models::Miners
    @rpc_controller    : Controllers::RPCController
    @phase             : Int32

    @last_conflicted : UInt32? = nil
    @cc : Int32 = 0
    @c0 : Int32 = 0
    @c1 : Int32 = 0
    @c2 : Int32 = 0
    @c3 : Int32 = 0

    def initialize(
          @host : String,
          @port : Int32,
          connect_host : String?,
          connect_port : Int32?,
          @wallet : Wallet)

      @blockchain     = Blockchain.new(@wallet)
      @id             = Random::Secure.hex(16)
      @nodes          = Models::Nodes.new
      @miners         = Models::Miners.new
      @rpc_controller = Controllers::RPCController.new(@blockchain)
      @phase          = PHASE_NODE_RUNNING

      info "The node id is #{light_green(@id)}"

      connect(connect_host.not_nil!, connect_port.not_nil!) if connect_host && connect_port
    end

    private def connect(connect_host : String, connect_port : Int32)
      info "Connecting to #{light_green(connect_host)}:#{light_green(connect_port)}"

      known_nodes = @nodes.map { |n| n[:context] }

      socket = HTTP::WebSocket.new(connect_host, "/peer", connect_port)
      peer(socket)

      send(socket, M_TYPE_HANDSHAKE_NODE, { context: context, known_nodes: known_nodes })

      connect_async(socket)
    end

    private def connect_async(socket)
      spawn do
        socket.run
      rescue e : Exception
        handle_exception(socket, e)
      end
    end

    private def draw_routes!
      post "/rpc" { |context, params| @rpc_controller.exec(context, params) }
    end

    def run!
      @rpc_controller.set_node(self)

      draw_routes!

      info "Start running Garnet's node on #{light_green(@host)}:#{light_green(@port)}"

      node = HTTP::Server.new(@host, @port, handlers)
      node.listen
    end

    private def peer_handler : WebSocketHandler
      WebSocketHandler.new("/peer") { |socket, context| peer(socket) }
    end

    private def peer(socket : HTTP::WebSocket)

      socket.on_message do |message|
        message_json = JSON.parse(message)
        message_type = message_json["type"].as_i
        message_content = message_json["content"].to_s

        case message_type
        when M_TYPE_HANDSHAKE_MINER
          _handshake_miner(socket, message_content)
        when M_TYPE_HANDSHAKE_NODE
          _handshake_node(socket, message_content)
        when M_TYPE_HANDSHAKE_NODE_ACCEPTED
          _handshake_node_accepted(socket, message_content)
        when M_TYPE_FOUND_NONCE
          _found_nonce(socket, message_content)
        when M_TYPE_ADD_TRANSACTION
          _add_transaction(socket, message_content)
        when M_TYPE_BROADCAST_BLOCK
          _broadcast_block(socket, message_content)
        when M_TYPE_REQUEST_CHAIN
          _request_chain(socket, message_content)
        when M_TYPE_RECIEVE_CHAIN
          _recieve_chain(socket, message_content)
        end
      end

      socket.on_close do |_|
        reject!(socket, nil)
      end

    rescue e : Exception
      handle_exception(socket, e)
    end

    def broadcast_transaction(transaction : Transaction)
      raw_transaction = transaction.dup

      info "New transaction coming!"

      @blockchain.add_transaction(transaction)

      @nodes.each do |n|
        send(n[:socket], M_TYPE_ADD_TRANSACTION, { transaction: raw_transaction })
      end
    end

    private def handle_exception(socket, e : Exception)
      node = @nodes.find { |n| n[:socket] == socket }

      if error_message = e.message
        error error_message
      else
        error "Unknown error occured"
      end

      if n = node
        error "On: #{n[:context][:host]}:#{n[:context][:port]}"
      end

      @phase = PHASE_NODE_RUNNING
    end

    private def sync_chain(socket)
      @phase = PHASE_NODE_SYNCING

      if last_conflicted = @last_conflicted
        send(socket, M_TYPE_REQUEST_CHAIN, { last_index: last_conflicted - 1 })
        @last_conflicted = nil
      else
        send(socket, M_TYPE_REQUEST_CHAIN, { last_index: 0 })
      end
    end

    private def analytics
      info "[Recieved block] Total: #{light_cyan(@cc)}, New block: #{light_cyan(@c0)}, " +
           "Conflict: #{light_cyan(@c1)}, Sync chain: #{light_cyan(@c2)}, Old block: #{light_cyan(@c3)}"
    end

    private def _handshake_miner(socket, _content)
      return unless @phase == PHASE_NODE_RUNNING

      _m_content = M_CONTENT_HANDSHAKE_MINER.from_json(_content)
      address = _m_content.address

      miner = { socket: socket, address: address }

      @miners << miner

      info "New miner: #{light_green(miner[:address])} (#{@miners.size})"

      miner[:socket].send(@blockchain.last_block.to_json)
    end

    private def _handshake_node(socket, _content)
      return unless @phase == PHASE_NODE_RUNNING

      _m_content = M_CONTENT_HANDSHAKE_NODE.from_json(_content)

      node_context = _m_content.context
      known_nodes = _m_content.known_nodes

      return if @nodes.find { |n| n[:context][:id] == node_context[:id] }

      node_list = @nodes.map { |n|
        (n[:context][:id] == @id || known_nodes.includes?(n[:context])) ? nil : n[:context]
      }.compact

      send(socket, M_TYPE_HANDSHAKE_NODE_ACCEPTED, {
             context: context,
             node_list: node_list,
             last_index: @blockchain.last_index,
           })

      @nodes << { socket: socket, context: node_context }

      info "New node has been connected: #{light_cyan(node_context[:id])} (#{@nodes.size})"
    end

    private def _handshake_node_accepted(socket, _content)
      _m_content = M_CONTENT_HANDSHAKE_NODE_ACCEPTED.from_json(_content)

      node_context = _m_content.context
      node_list = _m_content.node_list
      last_index = _m_content.last_index

      @nodes << { socket: socket, context: node_context }

      info "Successfully connected to #{node_context[:id]} (#{@nodes.size})"

      node_list
        .reject { |nc| @nodes.find { |n| n[:context][:id] == nc[:id]} }
        .each { |nc| connect(nc[:host], nc[:port]) }

      return if last_index <= @blockchain.last_index || @phase == PHASE_NODE_SYNCING

      sync_chain(socket)
    end

    private def _found_nonce(socket, _content)
      return unless @phase == PHASE_NODE_RUNNING

      _m_content = M_CONTENT_FOUND_NONCE.from_json(_content)

      nonce = _m_content.nonce

      return unless block = @blockchain.push_block?(nonce)

      info "Found new nonce: #{light_green(nonce)}"

      @nodes.each do |n|
        send(n[:socket], M_TYPE_BROADCAST_BLOCK, { block: block })
      end

      broadcast_to_miners
    end

    private def _add_transaction(socket, _content)
      return unless @phase == PHASE_NODE_RUNNING

      _m_content = M_CONTENT_ADD_TRANSACTION.from_json(_content)

      transaction = _m_content.transaction

      return unless transaction.valid?(@blockchain, @blockchain.last_index, false)

      info "New transaction coming!"

      @blockchain.add_transaction(transaction)
    end

    private def _broadcast_block(socket, _content)
      _m_content = M_CONTENT_BROADCAST_BLOCK.from_json(_content)

      block = _m_content.block

      @cc += 1

      return analytics unless @phase == PHASE_NODE_RUNNING

      if @blockchain.last_index + 1 == block.index
        @c0 += 1

        unless @blockchain.push_block?(block)
          node = @nodes.find { |n| n[:socket] == socket }.not_nil!
          error "Pushed block is invalid coming from #{node[:context][:host]}:#{node[:context][:port]}"
          return analytics
        end

        info "New block coming! (HEIGHT: #{light_cyan(@blockchain.chain.size)})"

        broadcast_to_miners

      elsif @blockchain.last_index == block.index
        @c1 += 1

        node = @nodes.find { |n| n[:socket] == socket }.not_nil!

        warning "Blockchain conflicted with #{node[:context][:host]}:#{node[:context][:port]}"
        warning "ignore the block. (HEIGHT: #{light_cyan(@blockchain.chain.size)})"

        @last_conflicted ||= block.index

      elsif @blockchain.last_index + 1 < block.index
        @c2 += 1

        warning "Required new chain! (#{@blockchain.last_block.index} for #{block.index})"

        sync_chain(socket)
      else
        @c3 += 1

        warning "Recieved old block, will be ignored"
      end

      analytics
    end

    private def _request_chain(socket, _content)
      _m_content = M_CONTENT_REQUEST_CHAIN.from_json(_content)

      last_index = _m_content.last_index

      info "Chain request: #{last_index}"

      send(socket, M_TYPE_RECIEVE_CHAIN, { chain: @blockchain.subchain(last_index+1) })
    end

    private def _recieve_chain(socket, _content)
      _m_content = M_CONTENT_RECIEVE_CHAIN.from_json(_content)

      chain = _m_content.chain

      info "Recieved chain: #{chain.size}"

      current_last_index = @blockchain.last_index

      if @blockchain.replace_chain(chain)
        info "Chain updated: #{current_last_index} -> #{@blockchain.last_index}"
        @phase = PHASE_NODE_RUNNING
      else
        error "Error while syncing chain, retrying..."
        sync_chain(socket)
      end
    end

    private def reject!(socket : HTTP::WebSocket, _e : Exception?)
      info "A node has been removed. (#{@nodes.size})" if reject_node?(socket)
      info "A miner has been removed. (#{@miners.size})" if reject_miner?(socket)

      return unless e = _e

      if error_message = e.message
        error error_message
      else
        error e.backtrace.join("\n")
      end
    end

    private def reject_node?(socket : HTTP::WebSocket)
      nodes_size = @nodes.size
      @nodes.reject! { |node| node[:socket] == socket }
      nodes_size != @nodes.size
    end

    private def reject_miner?(socket : HTTP::WebSocket)
      miners_size = @miners.size
      @miners.reject! { |miner| miner[:socket] == socket }
      miners_size != @miners.size
    end

    private def broadcast_to_miners
      @miners.each do |miner|
        miner[:socket].send(@blockchain.last_block.to_json)
      end
    end

    private def handlers
      [
        peer_handler,
        route_handler,
      ]
    end

    private def context : Models::NodeContext
      {
        id: @id,
        host: @host,
        port: @port,
      }
    end

    include Logger
    include Router
    include Protocol
    include Common::Color
  end
end