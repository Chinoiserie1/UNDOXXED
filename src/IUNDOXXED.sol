// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct Sale {
  address signer;
  uint256 maxSupply;
  uint256 publicPrice;
  uint256 whitelistPrice;
  uint256 maxPerWallet;
  Status status;
  bool freezeSale;
  bool freezeURI;
}

enum Status {
  notInitialized,
  initialized,
  allolist,
  whitelist,
  publicMint,
  finished,
  paused
}

error SaleFreeze();
error URIFreeze();
error SaleNotInitialized();
error SaleAlreadyInitialized();
error PublicSaleNotStarted();
error WhitelistSaleNotStarted();
error MaxPerWalletReach();
error IncorrectValueSend();
error invalidSignature();