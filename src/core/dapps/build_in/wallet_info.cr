# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Sushi::Core::DApps::BuildIn

    struct TokenAmount
        JSON.mapping(
            name: String,
            amount: String
        )
        def initialize(@name : String, @amount : String); end
    end

    struct WalletTransaction
        JSON.mapping(
            transaction_id: String,
            block_index: String,
            kind: String,
            from: String,
            from_readable: String,
            category: String,
            datetime: String,
            status: String,
            rejection_reason: String
        )

        def initialize(@transaction_id : String, @block_index : String, @kind : String, @from : String, @from_readable : String, @category : String, @datetime : String, )
    end

    struct WalletInfoResponse
        JSON.mapping(
            address: String,
            readable: Array(String),
            tokens: Array(TokenAmount),
            recent_transactions: Array(WalletTransaction)  
        )
    end

  class WalletInfo < DApp
    def setup
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      false
    end

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      true
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      case call
      when "walle_info"
        return wallet_info(json, context, params)
      end

      nil
    end

    def wallet_info(json, context, params)
      context.response.print api_success(walle_info_impl)
      context
    end

    def wallet_info_impl(address)
        readable = database.get_domain_map_for_address(address)
        wallet_info_response = WalletInfoResponse.new(address, readable)
      
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end
  end
end
