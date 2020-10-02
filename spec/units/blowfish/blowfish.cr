# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./../../spec_helper"

include Axentro::Core
include Axentro::Core::Keys

describe BlowFish do
  it "should encrypt and decrypt" do
    encrypted = BlowFish.encrypt("password", "some-data")
    decrypted = BlowFish.decrypt("password", encrypted[:data], encrypted[:salt])
    decrypted.should eq("some-data")
  end
end
