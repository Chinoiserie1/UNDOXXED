// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct Sale {
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
  started,
  finished,
  paused
}

error SaleFreeze();
error URIFreeze();
error SaleNotInitialized();
error SaleAlreadyInitialized();
error SaleNotStarted();
error MaxPerWalletReach();
error IncorrectValueSend();