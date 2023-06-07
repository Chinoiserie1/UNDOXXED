// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct Sale {
  uint256 maxSupply;
  uint256 publicPrice;
  uint256 whitelistPrice;
  uint256 maxPerWallet;
  Status status;
  bool freeze;
}

enum Status {
  notInitialized,
  initialized,
  started,
  finished,
  paused
}

error SaleFreeze();
error SaleNotInitialized();
error SaleAlreadyInitialized();
error SaleNotStarted();
error MaxPerWalletReach();
error IncorrectValueSend();