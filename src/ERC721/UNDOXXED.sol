// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/Assembly/src/access/Ownable.sol";

import "lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/opengem-contracts/token/ERC721/extensions/ERC721PermanentURIs.sol";
import "lib/opengem-contracts/token/ERC721/extensions/ERC721PermanentProof.sol";

import "./IUNDOXXED.sol";
import "./verification/Verification.sol";

/**
 * @title UNDOXXED Book
 * @author chixx.eth
 * @notice ERC721 with 4 types of mint
 */
contract UNDOXXED is ERC721, Ownable, ERC2981, ERC721PermanentURIs, ERC721PermanentProof {
  using Strings for uint256;

  string private cover1URI = "YOUR BASE URI/1/";
  string private cover2URI = "YOUR BASE URI/2/";
  string private baseMediaURICover1 = "YOUR BASE URI MEDIA 1/";
  string private baseMediaURICover2 = "YOUR BASE URI MEDIA 1/";
  string private tokenProof1;
  string private tokenProof2;
  string private sufixURI = ".json";

  uint256 private maxSupply = 300;
  uint256 private token1 = 0;
  uint256 private token2 = 0;
  uint256 private whitelistPrice = 0.001 ether;
  uint256 private publicPrice = 0.0015 ether;

  uint256 private privateWhitelistCover1 = 0;
  uint256 private privateWhitelistCover2 = 0;

  uint256 private withdrawPercent = 6000;

  address private signer = 0x90D41fA17a8dF96E7dff80227b4FC7d208dFd026;

  address[2] private fundsReceivers;

  bool public isPublic;

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

  constructor () ERC721("UNDOXXED", "UNDX") {
    fundsReceivers = [msg.sender, 0x19C013b64b7B2c7DaA59b96514662B687665E852];
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
    if (_amount1 + signatureCheckToken1[_sign] > _amount1Sign) revert exceedAllowedToken1Mint();
    if (_amount2 + signatureCheckToken2[_sign] > _amount2Sign) revert exceedAllowedToken2Mint();
    if (token1 + _amount1 + privateWhitelistCover1 > maxSupply / 2) revert maxSupplyToken1Reach();
    if (token2 + _amount2 + privateWhitelistCover2 > maxSupply / 2) revert maxSupplyToken2Reach();

    unchecked {
      signatureCheckToken1[_sign] += _amount1;
      signatureCheckToken2[_sign] += _amount2;
    }

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
    if (_amount1 + signatureCheckToken1[_sign] > _amount1Sign) revert exceedAllowedToken1Mint();
    if (_amount2 + signatureCheckToken2[_sign] > _amount2Sign) revert exceedAllowedToken2Mint();
    if (token1 + _amount1 + privateWhitelistCover1 > maxSupply / 2) revert maxSupplyToken1Reach();
    if (token2 + _amount2 + privateWhitelistCover2 > maxSupply / 2) revert maxSupplyToken2Reach();
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
    if (_amount1 + signatureCheckToken1[_sign] > _amount1Sign) revert exceedAllowedToken1Mint();
    if (_amount2 + signatureCheckToken2[_sign] > _amount2Sign) revert exceedAllowedToken2Mint();
    if (_amount1 > 0 && privateWhitelistCover1 == 0) revert privateWhitelistToken1SoldOut();
    if (_amount2 > 0 && privateWhitelistCover2 == 0) revert privateWhitelistToken2SoldOut();

    unchecked {
      if ((_amount1 + _amount2) * whitelistPrice > msg.value) revert invalidAmountSend();
    }

    unchecked {
      signatureCheckToken1[_sign] += _amount1;
      signatureCheckToken2[_sign] += _amount2;
    }

    privateWhitelistCover1 -= _amount1;
    privateWhitelistCover2 -= _amount2;

    _mintToken1(receiver, _amount1);
    _mintToken2(receiver, _amount2);
  }

  /**
   * @dev Mint function for `publicMint`
   * 
   * Requirements:
   * 
   * - `_amount1` quantity token1 to mint
   * - `_amount2` quantity token2 to mint
   * - `msg.value` should be equal at (`_amount1` + `_amount2`) * `publicPrice`
   * 
   * NOTE: This function can only be callable when `isPublic` equal true
   * 
   */
  function mint(uint256 _amount1, uint256 _amount2)
    external
    payable
  {
    address receiver = msg.sender;
    if (!isPublic) revert PublicSaleNotStarted();
    if (token1 + _amount1 + privateWhitelistCover1 > maxSupply / 2) revert maxSupplyToken1Reach();
    if (token2 + _amount2 + privateWhitelistCover2 > maxSupply / 2) revert maxSupplyToken2Reach();
    unchecked {
      if ((_amount1 + _amount2) * publicPrice > msg.value) revert invalidAmountSend();
    }

    _mintToken1(receiver, _amount1);
    _mintToken2(receiver, _amount2);
  }

  // WHITHDRAW

  /**
   * @dev Withdraw contract balance to 2 differents address
   * 
   * NOTE: First address will receive the `withdrawPercent`,
   * second one will receive the remaining
   * 
   * Requirements:
   * 
   * - `fundsReceivers` should not be zero address
   * 
   */
  function withdraw() external onlyOwner {
    address first = fundsReceivers[0];
    address second = fundsReceivers[1];
    if (first == address(0) || second == address(0)) revert WihdrawToZeroAddress();
    uint256 totalValue = address(this).balance;
    if (totalValue == 0) revert whithdrawZeroValue();
    uint256 firstValue = totalValue * withdrawPercent / 10000;
    (bool success, ) = address(first).call{value: firstValue}("");
    if (!success) revert failWhithdraw();
    (success, ) = address(second).call{value: address(this).balance}("");
    if (!success) revert failWhithdraw();
  }

  // SETTER FUNCTIONS

  function setMaxSupply(uint256 _newMaxSupply) external onlyOwner {
    if (_newMaxSupply > 300) revert MaxSupplyCanNotBeMoreThan300();
    if (_newMaxSupply < 200) revert MaxSupplyCanNotBeLowerThan200();
    maxSupply = _newMaxSupply;
  }

  function setPublic() external onlyOwner {
    isPublic = true;
  }

  function setSigner(address _newSigner) external onlyOwner {
    signer = _newSigner;
  }

  function setWhitelistPrice(uint256 _newWhitelistPrice) external onlyOwner {
    whitelistPrice = _newWhitelistPrice;
  }

  function setPublicPrice(uint256 _newPublicPrice) external onlyOwner {
    publicPrice = _newPublicPrice;
  }

  function setPrivatewhitelistToken1(uint256 _amountToken1) external onlyOwner {
    if (token1 + _amountToken1 > maxSupply / 2) revert noSupplyAvailableToken1();
    if (_amountToken1 < privateWhitelistCover1)
      revert AmountCanNotBeLowerThanCurrent(privateWhitelistCover1);
    privateWhitelistCover1 = _amountToken1;
  }

  function setPrivatewhitelistToken2(uint256 _amountToken2) external onlyOwner {
    if (token1 + _amountToken2 > maxSupply / 2) revert noSupplyAvailableToken2();
    if (_amountToken2 < privateWhitelistCover2)
      revert AmountCanNotBeLowerThanCurrent(privateWhitelistCover2);
    privateWhitelistCover2 = _amountToken2;
  }

  function setDefaultRoyalties(address _recipient, uint96 _feeNumerator) external onlyOwner {
    _setDefaultRoyalty(_recipient, _feeNumerator);
  }

  /**
   * @dev Function set 2 address for withdraw funds.
   * 
   * NOTE:
   * 
   * - `_firstReceiver` should be the the address that will receive the `withdrawPercent`.
   * - `_secondReceiver` will receive the remaining balance.
   * 
   */
  function setFundsReceivers(address _firstReceiver, address _secondReceiver) external onlyOwner {
    fundsReceivers[0] = _firstReceiver;
    fundsReceivers[1] = _secondReceiver;
  }

  function setPercentReceiver(uint256 _percent) external onlyOwner {
    withdrawPercent = _percent;
  }

  function setCover1BaseURI(string calldata _newBaseURI) external onlyOwner {
    cover1URI = _newBaseURI;
  }

  function setCover2BaseURI(string calldata _newBaseURI) external onlyOwner {
    cover2URI = _newBaseURI;
  }

  function setBaseMediaURICover1(string calldata _newBaseURI) external onlyOwner {
    baseMediaURICover1 = _newBaseURI;
  }

  function setBaseMediaURICover2(string calldata _newBaseURI) external onlyOwner {
    baseMediaURICover2 = _newBaseURI;
  }

  function setTokenProof1(string calldata _tokenProof) external onlyOwner {
    tokenProof1 = _tokenProof;
  }

  function setTokenProof2(string calldata _tokenProof) external onlyOwner {
    tokenProof2 = _tokenProof;
  }

  function setSufixURI(string calldata _newSufixURI) external onlyOwner {
    sufixURI = _newSufixURI;
  }

  function addPermanentTokenURI(uint256 tokenId, string calldata tokenURI) external onlyOwner {
    _addPermanentTokenURI(tokenId, tokenURI);
  }

  // VIEW FUNCTIONS

  function getMaxSupplyCover() public view returns (uint256) {
    return maxSupply / 2;
  }

  function getToken1Supply() external view returns (uint256) {
    return token1;
  }

  function getToken2Supply() external view returns (uint256) {
    return token2;
  }

  function getAllSupply() external view returns (uint256) {
    return token1 + token2;
  }

  function getWhitelistPrice() external view returns (uint256) {
    return whitelistPrice;
  }

  function getPublicPrice() external view returns (uint256) {
    return publicPrice;
  }

  function getDescription() external pure returns (string memory) {
    return "UNDOXXED, the finest in digital lifestyle culture, is an annual hybrid book that merges street and lifestyle culture with the digital world. It focuses on fashion, sneakers, and streetwear, cataloging the best of phygital culture. This publication bridges the physical and digital realms within the evolving Web3 space.";
  }

  // function getTokenName(uint256 _tokenId) external pure returns (string memory) {
  //   if (_tokenId < 151) {
  //     return string(abi.encodePacked("UNDXX vol.1 Black #", _tokenId.toString(), "/300"));
  //   }
  //   return string(abi.encodePacked("UNDXX vol.1 Purple #", _tokenId.toString(), "/300"));
  // }

  // function getTokenMedia(uint256 _tokenId) external view returns (string memory) {
  //   if (_tokenId < 151) {
  //     return baseMediaURICover1;
  //   }
  //   return baseMediaURICover2;
  // }

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
    string[] memory uris = tokenURIsPermanent(tokenId);

    return uris[0];
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721PermanentURIs, ERC721PermanentProof) {
    super._burn(tokenId);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 firstTokenId,
    uint256 batchSize
  ) internal virtual override(ERC721) {
    super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
  }

  // INTERNAL FUNCTIONS

  function _mintToken1(address _to, uint256 _amount) internal {
    unchecked {
      for (uint256 i = 0; i < _amount; ++i) {
        uint256 nextId = token1 + token2 + 1;
        _mint(_to, nextId);
        _addPermanentTokenURI(nextId, cover1URI);
        _setPermanentTokenProof(nextId, tokenProof1);
        ++token1;
      }
    }
  }

  function _mintToken2(address _to, uint256 _amount) internal {
    unchecked {
      for (uint256 i = 0; i < _amount; ++i) {
        uint256 nextId = token1 + token2 + 1;
        _mint(_to, nextId);
        _addPermanentTokenURI(nextId, cover2URI);
        _setPermanentTokenProof(nextId, tokenProof2);
        ++token2;
      }
    }
  }
}