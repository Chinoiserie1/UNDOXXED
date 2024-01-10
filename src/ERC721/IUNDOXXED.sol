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

error ZeroAddress();
error contractFreezed();
error onlyApprovedPaymentAddress();
error maxSupplyToken1Reach();
error maxSupplyToken2Reach();
error invalidAmountSend();
error maxMintWalletReachToken1();
error maxMintWalletReachToken2();
error invalidSaleStatus();
error PublicSaleNotStarted();
error invalidSignature();
error exceedAllowedToken1Mint();
error exceedAllowedToken2Mint();
error failWhithdraw();
error whithdrawZeroValue();
error privateWhitelistToken1SoldOut();
error privateWhitelistToken2SoldOut();
error NoReserveToken1();
error NoReserveToken2();
error noSupplyAvailableToken1();
error noSupplyAvailableToken2();
error AmountCanNotBeLowerThanCurrent(uint256);
error WihdrawToZeroAddress();
error MaxSupplyCanNotBeMoreThan500();
error MaxSupplyCanNotbeOdd();
error MaxSupplyCanNotBeLowerThanActual();
error FeeExceed10Percent();
error PercentCanNotBeMoreThan100Percent();
error SupplySealed();

