# frozen_string_literal: true

describe DoiMintingJob do
  context "when doi blank" do
    it "returns nil"
  end
  context "when doi minted" do
    it "returns nil"
  end
  context "when doi pending" do
    it "calls the DoiMintingService"
  end
end
