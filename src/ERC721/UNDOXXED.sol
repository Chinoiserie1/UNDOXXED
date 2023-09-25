// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "lib/Assembly/src/access/Ownable.sol";

import "lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "lib/opengem-contracts/token/ERC721/extensions/ERC721PermanentURIs.sol";

import "./verification/Verification.sol";

error contractFreezed();
error onlyApprovedPaymentAddress();
error maxSupplyToken1Reach();
error maxSupplyToken2Reach();
error invalidAmountSend();
error maxMintWalletReachToken1();
error maxMintWalletReachToken2();
error invalidSaleStatus();
error invalidSignature();

contract UNDOXXED is ERC721Enumerable, Ownable, ERC2981, ERC721PermanentURIs {
  uint256 private maxSupply = 500;
  uint256 private maxMintWallet = 5;
  uint256 private token1 = 1;
  uint256 private token2 = 251;
  uint256 private whitelistPrice = 0.1 ether;
  uint256 private publicPrice = 0.15 ether;

  address private signer;

  bool private contractFreeze;

  Status private status;

  mapping(address => bool) private fiatPayment;
  mapping(address => mapping(uint256 => uint256)) private mintPerWallet;

  modifier freezed {
    if (contractFreeze) revert contractFreezed();
    _;
  }

  modifier checkStatus(Status _status) {
    if (status != _status) revert invalidSaleStatus();
    _;
  }

  /**
   * @notice verify signature
   */
  modifier verify(
    address _to,
    uint256 _amount1,
    uint256 _amount2,
    Status _status,
    bytes memory _sign
  ) {
    if (!Verification.verifySignature(signer, _to, _amount1, _amount2, _status, _sign))
      revert invalidSignature();
    _;
  }

  constructor () ERC721("UNDOXXED", "UNDX") {}

  function allowlistMint(address _to, uint256 _amount1, uint256 _amount2, bytes memory _sign)
    external
    checkStatus(Status.allowlist)
    verify(_to, _amount1, _amount2, Status.allowlist, _sign)
  {
    if (msg.sender != _to) {
      if (!fiatPayment[msg.sender]) revert onlyApprovedPaymentAddress();
    }
    if (mintPerWallet[_to][1] + _amount1 > maxMintWallet) revert maxMintWalletReachToken1();
    if (mintPerWallet[_to][2] + _amount2 > maxMintWallet) revert maxMintWalletReachToken1();

    _mintToken1(_to, _amount1);
    _mintToken2(_to, _amount2);
  }

  function whitelistMint(address _to, uint256 _amount1, uint256 _amount2, bytes memory _sign)
    external
    payable
    checkStatus(Status.whitelist)
    verify(_to, _amount1, _amount2, Status.whitelist, _sign)
  {
    if (msg.sender != _to) {
      if (!fiatPayment[msg.sender]) revert onlyApprovedPaymentAddress();
    }
    if (mintPerWallet[_to][1] + _amount1 > maxMintWallet) revert maxMintWalletReachToken1();
    if (mintPerWallet[_to][2] + _amount2 > maxMintWallet) revert maxMintWalletReachToken1();
    unchecked {
      if ((_amount1 + _amount2) * whitelistPrice > msg.value) revert invalidAmountSend();
    }

    _mintToken1(_to, _amount1);
    _mintToken2(_to, _amount2);
  }

  function mint(address _to, uint256 _amount1, uint256 _amount2)
    external
    payable
    checkStatus(Status.publicMint)
  {
    if (msg.sender != _to) {
      if (!fiatPayment[msg.sender]) revert onlyApprovedPaymentAddress();
    }
    if (mintPerWallet[_to][1] + _amount1 > maxMintWallet) revert maxMintWalletReachToken1();
    if (mintPerWallet[_to][2] + _amount2 > maxMintWallet) revert maxMintWalletReachToken1();
    unchecked {
      if ((_amount1 + _amount2) * publicPrice > msg.value) revert invalidAmountSend();
    }

    _mintToken1(_to, _amount1);
    _mintToken2(_to, _amount2);
  }

  function setStatus(Status _newStatus) external onlyOwner freezed {
    status = _newStatus;
  }

  function setMaxMintWallet(uint256 _newMaxMintWallet) external onlyOwner freezed {
    maxMintWallet = _newMaxMintWallet;
  }

  function setDefaultRoyalties(address _recipient, uint96 _feeNumerator) external onlyOwner {
    _setDefaultRoyalty(_recipient, _feeNumerator);
  }

  function freezeContract() external onlyOwner freezed {
    contractFreeze = true;
  }

  // OVERRIDE FUNCTIONS

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC2981, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  // INTERNAL FUNCTIONS

  function _mintToken1(address _to, uint256 _amount) internal {
    unchecked {
      if (token1 + _amount > 250) revert maxSupplyToken1Reach();
      for (uint256 i = 0; i < _amount; i++) {
        _mint(_to, token1);
      }
      token1 += _amount;
      mintPerWallet[_to][1] += _amount;
    }
  }

  function _mintToken2(address _to, uint256 _amount) internal {
    unchecked {
      if (token2 + _amount > 500) revert maxSupplyToken2Reach();
      for (uint256 i = 0; i < _amount; i++) {
        _mint(_to, token2);
      }
      token2 += _amount;
      mintPerWallet[_to][2] += _amount;
    }
  }
}