// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC2981} from "lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721PermanentURIs} from "lib/opengem-contracts/token/ERC721/extensions/ERC721PermanentURIs.sol";
import {ERC721PermanentProof} from "lib/opengem-contracts/token/ERC721/extensions/ERC721PermanentProof.sol";

import "./IUNDOXXED.sol";
import "./verification/Verification.sol";

/**
 * @title UNDOXXED Book
 * @author chixx.eth
 * @notice ERC721 with 4 types of mint
 */
contract UNDOXXEDBOOK24 is ERC721, Ownable, ERC2981, ERC721PermanentProof {
  string private cover1URI = "ipfs://Qmbo6MEp788EKWf3YGRkRxDVrbEL1L3Zj4c2C4W2EGDXnU";
  string private cover2URI = "ipfs://QmPojiTQyZk7cpJ3LvbHroJJNptoX45ZLj1r5RUeWqdSyX";
  string private baseMediaURICover = "ipfs://QmXSwaTSgMaiER1zKM6mdjjAD6YMXeEgQBBBFhd4vvtCVk";
  string private baseMediaURICoverArweave = "ar://-bk2F28vmvghWo90grBHKbC12ATIjgKG3NL0G2t0G1c";
  /** @dev sha256 JSON hashed */
  string private tokenProof1 = "8d39748984ce311a99f51fec1295f4e6c2c432e38617001e879a066150bb4f1c";
  string private tokenProof2 = "003d43ec4ff0e42e297825e3c1ee0838a6191b44dfb3cb5aa11cb5653fc1dc9d";

  uint256 private maxSupply = 300;
  uint256 private token1 = 0;
  uint256 private token2 = 0;
  uint256 private whitelistPrice = 0.074 ether;
  uint256 private publicPrice = 0.091 ether;

  uint256 public cover1Reserved = 40;
  uint256 public cover2Reserved = 35;


  /** @dev 1% => 100, `withdrawPercent` / 10 000 */
  uint256 private withdrawPercent = 6000;

  address private signer = 0x90D41fA17a8dF96E7dff80227b4FC7d208dFd026;

  address[2] private fundsReceivers;

  bool public isPublic;
  bool public supplySealed;

  mapping(bytes => uint256) private signatureCheckToken1;
  mapping(bytes => uint256) private signatureCheckToken2;

  /**
   * @dev verify signature
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

  constructor () ERC721("UNDOXXED BOOK Vol.1", "UNDXX24") {
    fundsReceivers = [msg.sender, 0x19C013b64b7B2c7DaA59b96514662B687665E852];
    _setDefaultRoyalty(msg.sender, 300);
  }

  // MINT FUNCTIONS

  /**
   * @dev Mint function for `allowlist`
   * 
   * Requirements:
   * 
   * - `_amount1` quantity token1 to mint
   * - `_amount2` quantity token2 to mint
   * - `_amount1Sign` quantity token1 user allowed to mint
   * - `_amount2Sign` quantity token2 user allowed to mint
   * - `_sign` the signature
   * - reserve should be set
   * 
   */
  function allowlistMint(
    uint256 _amount1,
    uint256 _amount2,
    uint256 _amount1Sign,
    uint256 _amount2Sign,
    bytes memory _sign
  )
    external
    verify(msg.sender, _amount1Sign, _amount2Sign, Status.allowlist, _sign)
  {
    address receiver = msg.sender;
    uint256 maxTokenSupply = getMaxSupplyCover();
    if (_amount1 + signatureCheckToken1[_sign] > _amount1Sign) revert exceedAllowedToken1Mint();
    if (_amount2 + signatureCheckToken2[_sign] > _amount2Sign) revert exceedAllowedToken2Mint();
    if (token1 + _amount1 > maxTokenSupply) revert maxSupplyToken1Reach();
    if (token2 + _amount2 > maxTokenSupply) revert maxSupplyToken2Reach();
    if (_amount1 > cover1Reserved) revert NoReserveToken1();
    if (_amount2 > cover2Reserved) revert NoReserveToken2();

    unchecked {
      signatureCheckToken1[_sign] += _amount1;
      signatureCheckToken2[_sign] += _amount2;
    }

    cover1Reserved -= _amount1;
    cover2Reserved -= _amount2;

    _mintToken1(receiver, _amount1);
    _mintToken2(receiver, _amount2);
  }

  /**
   * @dev Mint function for `whitelist`
   * 
   * Requirements:
   * 
   * - `_amount1` quantity token1 to mint
   * - `_amount2` quantity token2 to mint
   * - `_amount1Sign` quantity token1 user allowed to mint
   * - `_amount2Sign` quantity token2 user allowed to mint
   * - `_sign` the signature
   * - `msg.value` should be equal at (`_amount1` + `_amount2`) * `whitelistPrice`
   * 
   */
  function whitelistMint(
    uint256 _amount1,
    uint256 _amount2,
    uint256 _amount1Sign,
    uint256 _amount2Sign,
    bytes memory _sign
  )
    external
    payable
    verify(msg.sender, _amount1Sign, _amount2Sign, Status.whitelist, _sign)
  {
    address receiver = msg.sender;
    uint256 maxTokenSupply = getMaxSupplyCover();
    if (_amount1 + signatureCheckToken1[_sign] > _amount1Sign) revert exceedAllowedToken1Mint();
    if (_amount2 + signatureCheckToken2[_sign] > _amount2Sign) revert exceedAllowedToken2Mint();
    if (token1 + _amount1 + cover1Reserved > maxTokenSupply) revert maxSupplyToken1Reach();
    if (token2 + _amount2 + cover2Reserved > maxTokenSupply) revert maxSupplyToken2Reach();
    unchecked {
      if ((_amount1 + _amount2) * whitelistPrice > msg.value) revert invalidAmountSend();
    }

    unchecked {
      signatureCheckToken1[_sign] += _amount1;
      signatureCheckToken2[_sign] += _amount2;
    }

    _mintToken1(receiver, _amount1);
    _mintToken2(receiver, _amount2);
  }

  /**
   * @dev Mint function for `privateWhitelist`
   * 
   * Requirements:
   * 
   * - `_amount1` quantity token1 to mint
   * - `_amount2` quantity token2 to mint
   * - `_amount1Sign` quantity token1 user allowed to mint
   * - `_amount2Sign` quantity token2 user allowed to mint
   * - `_sign` the signature
   * - `msg.value` should be equal at (`_amount1` + `_amount2`) * `whitelistPrice`
   * 
   * NOTE: This function can only be callable when status is `whitelist` or `publicMint`
   * 
   */
  function privateWhitelistMint(
    uint256 _amount1,
    uint256 _amount2,
    uint256 _amount1Sign,
    uint256 _amount2Sign,
    bytes memory _sign
  )
    external
    payable
    verify(msg.sender, _amount1Sign, _amount2Sign, Status.privateWhitelist, _sign)
  {
    address receiver = msg.sender;
    uint256 maxTokenSupply = getMaxSupplyCover();
    if (_amount1 + signatureCheckToken1[_sign] > _amount1Sign) revert exceedAllowedToken1Mint();
    if (_amount2 + signatureCheckToken2[_sign] > _amount2Sign) revert exceedAllowedToken2Mint();
    if (token1 + _amount1 > maxTokenSupply) revert maxSupplyToken1Reach();
    if (token2 + _amount2 > maxTokenSupply) revert maxSupplyToken2Reach();
    if (_amount1 > cover1Reserved) revert NoReserveToken1();
    if (_amount2 > cover2Reserved) revert NoReserveToken2();

    unchecked {
      if ((_amount1 + _amount2) * whitelistPrice > msg.value) revert invalidAmountSend();
    }

    unchecked {
      signatureCheckToken1[_sign] += _amount1;
      signatureCheckToken2[_sign] += _amount2;
    }

    cover1Reserved -= _amount1;
    cover2Reserved -= _amount2;

    _mintToken1(receiver, _amount1);
    _mintToken2(receiver, _amount2);
  }

  /**
   * @dev Mint function for `publicMint`.
   * 
   * Requirements:
   * 
   * - `_amount1` quantity token1 to mint.
   * - `_amount2` quantity token2 to mint.
   * - `msg.value` should be equal at (`_amount1` + `_amount2`) * `publicPrice`.
   * 
   * NOTE: This function can only be callable when `isPublic` equal true.
   * 
   */
  function mint(uint256 _amount1, uint256 _amount2)
    external
    payable
  {
    address receiver = msg.sender;
    uint256 maxTokenSupply = getMaxSupplyCover();
    if (!isPublic) revert PublicSaleNotStarted();
    if (token1 + _amount1 + cover1Reserved > maxTokenSupply) revert maxSupplyToken1Reach();
    if (token2 + _amount2 + cover2Reserved > maxTokenSupply) revert maxSupplyToken2Reach();
    unchecked {
      if ((_amount1 + _amount2) * publicPrice > msg.value) revert invalidAmountSend();
    }

    _mintToken1(receiver, _amount1);
    _mintToken2(receiver, _amount2);
  }

  // WHITHDRAW

  /**
   * @dev Withdraw contract balance to 2 differents address.
   * 
   * NOTE: First address will receive the `withdrawPercent`,
   * second one will receive the remaining.
   * 
   * Requirements:
   * 
   * - `fundsReceivers` each address should not be zero address.
   * 
   */
  function withdraw() external onlyOwner {
    if (fundsReceivers[0] == address(0) || fundsReceivers[1] == address(0)) revert WihdrawToZeroAddress();
    uint256 totalValue = address(this).balance;
    if (totalValue == 0) revert whithdrawZeroValue();
    uint256 firstValue = totalValue * withdrawPercent / 10000;
    (bool success, ) = address(fundsReceivers[0]).call{value: firstValue}("");
    if (!success) revert failWhithdraw();
    (success, ) = address(fundsReceivers[1]).call{value: totalValue - firstValue}("");
    if (!success) revert failWhithdraw();
  }

  function emergencyWithdraw() external onlyOwner {
    (bool success, ) = address(msg.sender).call{value: address(this).balance}("");
    if (!success) revert failWhithdraw();
  }

  // SETTER FUNCTIONS

  /**
   * @dev Set a new max supply.
   * 
   * Requirements:
   * 
   * - `_newMaxSupply` should be in the range of 200 to 300.
   * - `_newMaxSupply` should be even.
   * 
   */
  function setMaxSupply(uint256 _newMaxSupply) external onlyOwner {
    if (_newMaxSupply > 500) revert MaxSupplyCanNotBeMoreThan500();
    if (_newMaxSupply % 2 == 1) revert MaxSupplyCanNotbeOdd();
    if (_newMaxSupply < getAllSupply() + getTotalReservedCover()) revert MaxSupplyCanNotBeLowerThanActual();
    if (supplySealed) revert SupplySealed();
    maxSupply = _newMaxSupply;
  }

  /**
   * @dev Set `isPublic` to true for enable public mint.
   */
  function setPublic(bool _public) external onlyOwner {
    isPublic = _public;
  }

  /**
   * @dev Set the address that sign all signatures.
   * 
   * NOTE: Previous signature will no longer be valid.
   */
  function setSigner(address _newSigner) external onlyOwner {
    signer = _newSigner;
  }

  /**
   * @dev Set the whitelist price.
   */
  function setWhitelistPrice(uint256 _newWhitelistPrice) external onlyOwner {
    whitelistPrice = _newWhitelistPrice;
  }

  /**
   * @dev Set the public price.
   */
  function setPublicPrice(uint256 _newPublicPrice) external onlyOwner {
    publicPrice = _newPublicPrice;
  }

  /**
   * @dev Set the amount of token1 to be reserved.
   */
  function setReserveToken1(uint256 _amountToken1) external onlyOwner {
    if (token1 + _amountToken1 > getMaxSupplyCover()) revert noSupplyAvailableToken1();
    cover1Reserved = _amountToken1;
  }

  /**
   * @dev Set the amount of token2 to be reserved.
   */
  function setReserveToken2(uint256 _amountToken2) external onlyOwner {
    if (token2 + _amountToken2 > getMaxSupplyCover()) revert noSupplyAvailableToken2();
    cover2Reserved = _amountToken2;
  }

  /**
   * @dev Set royalties inforamtions.
   * 
   * NOTE: `_feeNumerator` should be `_feeNumerator` / 10000.
   * 
   */
  function setDefaultRoyalties(address _recipient, uint96 _feeNumerator) external onlyOwner {
    if (_feeNumerator > 1000) revert FeeExceed10Percent();
    _setDefaultRoyalty(_recipient, _feeNumerator);
  }

  /**
   * @dev Set 2 address for withdraw funds.
   * 
   * NOTE:
   * 
   * - `_firstReceiver` should be the the address that will receive the `withdrawPercent`.
   * - `_secondReceiver` will receive the remaining balance.
   * 
   */
  function setFundsReceivers(address _firstReceiver, address _secondReceiver) external onlyOwner {
    if (_firstReceiver == address(0) || _secondReceiver == address(0)) revert ZeroAddress();
    fundsReceivers[0] = _firstReceiver;
    fundsReceivers[1] = _secondReceiver;
  }

  /**
   * @dev Set the percent the first address wil be funded when withdraw.
   */
  function setPercentReceiver(uint256 _percent) external onlyOwner {
    if (_percent > 10000) revert PercentCanNotBeMoreThan100Percent();
    withdrawPercent = _percent;
  }

  /**
   * @dev Seal the max supply.
   */
  function sealSupply() external onlyOwner {
    maxSupply = getAllSupply();
    supplySealed = true;
  }

  // VIEW FUNCTIONS

  /**
   * @dev Return the max supply mintable
   */
  function getMaxSupply() external view returns (uint256) {
    return maxSupply;
  }

  /**
   * @dev Return the max supply of a cover.
   */
  function getMaxSupplyCover() public view returns (uint256) {
    return maxSupply / 2;
  }

  /**
   * @dev Return total cover 1 minted.
   */
  function getToken1Supply() external view returns (uint256) {
    return token1;
  }

  /**
   * @dev Return total cover 2 minted.
   */
  function getToken2Supply() external view returns (uint256) {
    return token2;
  }

  /**
   * @dev Return supply minted.
   */
  function getAllSupply() public view returns (uint256) {
    return token1 + token2;
  }

  /**
   * @dev Return the whitelist price.
   */
  function getWhitelistPrice() external view returns (uint256) {
    return whitelistPrice;
  }

  /**
   * @dev Return the public price.
   */
  function getPublicPrice() external view returns (uint256) {
    return publicPrice;
  }

  /**
   * @dev Return the amount mint for each cover by a specific signature.
   */
  function getBalanceMintBySign(bytes memory _sign) external view returns (uint256 cover1, uint256 cover2) {
    cover1 = signatureCheckToken1[_sign];
    cover2 = signatureCheckToken2[_sign];
  }

  function getTotalReservedCover() public view returns (uint256) {
    return cover1Reserved + cover2Reserved;
  }

  /**
   * @dev Return the description of the nft.
   */
  function getDescription() external pure returns (string memory) {
    return "UNDOXXED, the finest in digital lifestyle culture, is an annual hybrid book that merges street and lifestyle culture with the digital world. It focuses on fashion, sneakers, and streetwear, cataloging the best of phygital culture. This publication bridges the physical and digital realms within the evolving Web3 space. 3D by Ryan Owers, Art Direction and Music by XERAK.";
  }

  /**
   * @dev Returns the name of a specific tokenId.
   */
  function getTokenName(uint256 _tokenId) external view returns (string memory) {
    if (keccak256(bytes(tokenProofPermanent(_tokenId))) == keccak256(bytes(tokenProof1))) {
      return string("UNDOXXED BOOK vol.1 Black");
    }
    return string("UNDOXXED BOOK vol.1 Purple");
  }

  /**
   * @dev Return the media from ipfs and arweave.
   */
  function getTokenMediaPermanent() external view returns (string[2] memory) {
    return [baseMediaURICover, baseMediaURICoverArweave];
  }

  /**
   * @dev Return the sha256 of the media.
   */
  function getMediaProofPermanent() external pure returns (string memory) {
    return "ab57c888aa9d13029b64f563ec18941eca5054ad002a35fffd4a68022975dc45";
  }

  // OVERRIDE FUNCTIONS

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC2981, ERC721)
    returns(bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    if (!_exists(tokenId)) return "";
    if (keccak256(bytes(tokenProofPermanent(tokenId))) == keccak256(bytes(tokenProof1))) {
      return cover1URI;
    }
    return cover2URI;
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721PermanentProof) {
    super._burn(tokenId);
  }

  // INTERNAL FUNCTIONS

  function _mintToken1(address _to, uint256 _amount) internal {
    unchecked {
      for (uint256 i = 0; i < _amount; ++i) {
        uint256 nextId = getAllSupply() + 1;
        _mint(_to, nextId);
        _setPermanentTokenProof(nextId, tokenProof1);
        ++token1;
      }
    }
  }

  function _mintToken2(address _to, uint256 _amount) internal {
    unchecked {
      for (uint256 i = 0; i < _amount; ++i) {
        uint256 nextId = getAllSupply() + 1;
        _mint(_to, nextId);
        _setPermanentTokenProof(nextId, tokenProof2);
        ++token2;
      }
    }
  }
}