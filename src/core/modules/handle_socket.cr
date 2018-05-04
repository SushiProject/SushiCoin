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

require "./logger"

module ::Sushi::Core
  abstract class HandleSocket

    def send(socket, t, content)
      socket.send({type: t, content: content.to_json}.to_json)
    rescue e : Exception
      handle_exception(socket, e)
    end

    def handle_exception(socket : HTTP::WebSocket, e : Exception)
      case e
      when IO::Error
        clean_connection(socket)
      else
        if error_message = e.message
          error error_message
        else
          error "unknown error"
        end

        if backtrace = e.backtrace
          error backtrace.join("\n")
        end
      end
    end

    abstract def clean_connection(socket)

    include Logger
  end
end
