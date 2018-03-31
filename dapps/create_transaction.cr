module ::Sushi::Core::DApps::User
  class CreateTransaction < UserDApp
    #
    # The target action name in transaction's field
    #
    TARGET_ACTION = "create_transaction_sample"

    #
    # The address is coming from wallets/testnet-0.json
    #
    VALID_ADDRESS = "VDAxMjJmMTcyNWE1NmE0MjExZTk0ZThkMGRiYmM2ZjE1YTQ5OWRmODM1MzliYmUy"

    def valid_addresses
      [VALID_ADDRESS]
    end

    def valid_networks
      ["testnet"]
    end

    def related_transaction_actions
      [TARGET_ACTION]
    end

    def valid_transaction?(transaction, prev_transactions)
      raise "the token must be #{TOKEN_DEFAULT}" unless transaction.token == TOKEN_DEFAULT
      raise "the number of senders must be 1" unless transaction.senders.size == 1
      raise "the number of recipients must be 1" unless transaction.recipients.size == 1
      raise "the recipient address must be #{VALID_ADDRESS}" unless transaction.recipients[0][:address] == VALID_ADDRESS
      raise "the sending amount must be 10" unless transaction.senders[0][:amount] == 10

      true
    end

    def new_block(block)
      block.transactions.each do |transaction|
        if transaction.action == TARGET_ACTION
          info "found a #{TARGET_ACTION} transaction"

          sender = create_sender(5_i64)
          recipient = create_recipient(transaction.senders[0][:address], 5_i64)

          #
          # You can create an id for a target transaction by
          # `create_id_for_transaction`
          #
          # If you create it manually, note that every node must create same id for an action.
          # Otherwise, duplicated transactions for 1 action will be accepted,
          # if you run the dApp on multiple nodes.
          #
          # `sha256` is useful method to create an id.
          #
          id = create_id_for_transaction(transaction)

          created = create_transaction(
            id,                                                       # id
            "send",                                                   # action
            sender,                                                   # sender
            recipient,                                                # recipient
            "Thanks for sending me 10 SHARI! I'll back you 5 SHARI!", # message
            TOKEN_DEFAULT,                                            # token
          )

          info "created a transaction from CreateTranscation(UserDApp): #{id}" if created
        end
      end
    end

    def define_rpc?(call, json, context)
      nil
    end
  end
end
