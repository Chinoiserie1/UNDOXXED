// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

enum Status {
  notInitialized,
  allowlist,
  whitelist,
  publicMint,
  finished,
  paused,
  privateWhitelist
}

error contractFreezed();
error onlyApprovedPaymentAddress();
error maxSupplyToken1Reach();
error maxSupplyToken2Reach();
error invalidAmountSend();
error maxMintWalletReachToken1();
error maxMintWalletReachToken2();
error invalidSaleStatus();
error invalidSignature();
error exceedAllowedToken1Mint();
error exceedAllowedToken2Mint();
error failWhithdraw();
error whithdrawZeroValue();
error privateWhitelistToken1SoldOut();
error privateWhitelistToken2SoldOut();
error noSupplyAvailableToken1();
error noSupplyAvailableToken2();
error invalidAmountCanNotBeLowerThanCurrent(uint256);

