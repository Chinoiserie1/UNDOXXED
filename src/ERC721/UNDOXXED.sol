// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/Assembly/src/access/Ownable.sol";

import "lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "lib/opengem-contracts/token/ERC721/extensions/ERC721PermanentURIs.sol";

import "./IUNDOXXED.sol";
import "./verification/Verification.sol";

/**
 * @title UNDOXXED Book
 * @author chixx.eth
 * @notice ERC721 with 3 types of mint
 */
contract UNDOXXED is ERC721Enumerable, Ownable, ERC2981, ERC721PermanentURIs {
  using Strings for uint256;

  string private baseURI = "YOUR BASE URI/";  
  string private baseMediaURICover1 = "YOUR BASE URI/";
  string private baseMediaURICover2 = "YOUR BASE URI/";
  string private sufixURI = ".json";

  uint256 private maxSupply = 200;
  uint256 private maxMintWallet = 10;
  uint256 private token1 = 1;
  uint256 private token2 = 101;
  uint256 private whitelistPrice = 0.001 ether;
  uint256 private publicPrice = 0.0015 ether;

  address private signer = 0x90D41fA17a8dF96E7dff80227b4FC7d208dFd026;

  bool private contractFreeze;

  Status private status;

  mapping(address => bool) private fiatPayment;
  mapping(address => mapping(uint256 => uint256)) private mintPerWallet;
  mapping(bytes => uint256) private signatureCheckToken1;
  mapping(bytes => uint256) private signatureCheckToken2;

  /**
   * @notice check if the contract is freeze
   */
  modifier freezed {
    if (contractFreeze) revert contractFreezed();
    _;
  }

  /**
   * @notice check the current status
   */
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

  // MINT FUNCTIONS

  function allowlistMint(
    address _to,
    uint256 _amount1,
    uint256 _amount2,
    uint256 _amount1Sign,
    uint256 _amount2Sign,
    bytes memory _sign
  )
    external
    checkStatus(Status.allowlist)
    verify(_to, _amount1Sign, _amount2Sign, Status.allowlist, _sign)
  {
    if (msg.sender != _to) {
      if (!fiatPayment[msg.sender]) revert onlyApprovedPaymentAddress();
    }
    if (_amount1 + signatureCheckToken1[_sign] > _amount1Sign) revert exceedAllowedToken1Mint();
    if (_amount2 + signatureCheckToken2[_sign] > _amount2Sign) revert exceedAllowedToken2Mint();

    unchecked {
      signatureCheckToken1[_sign] += _amount1;
      signatureCheckToken2[_sign] += _amount2;
    }

    _mintToken1(_to, _amount1);
    _mintToken2(_to, _amount2);
  }

  function whitelistMint(
    address _to,
    uint256 _amount1,
    uint256 _amount2,
    uint256 _amount1Sign,
    uint256 _amount2Sign,
    bytes memory _sign
  )
    external
    payable
    verify(_to, _amount1Sign, _amount2Sign, Status.whitelist, _sign)
  {
    if (status != Status.whitelist || status != Status.publicMint) revert invalidSaleStatus();
    if (msg.sender != _to) {
      if (!fiatPayment[msg.sender]) revert onlyApprovedPaymentAddress();
    }
    if (_amount1 + signatureCheckToken1[_sign] > _amount1Sign) revert exceedAllowedToken1Mint();
    if (_amount2 + signatureCheckToken2[_sign] > _amount2Sign) revert exceedAllowedToken2Mint();
    unchecked {
      if ((_amount1 + _amount2) * whitelistPrice > msg.value) revert invalidAmountSend();
    }

    unchecked {
      signatureCheckToken1[_sign] += _amount1;
      signatureCheckToken2[_sign] += _amount2;
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
    if (mintPerWallet[_to][2] + _amount2 > maxMintWallet) revert maxMintWalletReachToken2();
    unchecked {
      if ((_amount1 + _amount2) * publicPrice > msg.value) revert invalidAmountSend();
    }

    _mintToken1(_to, _amount1);
    _mintToken2(_to, _amount2);
  }

  function fiatPaymentMint(
    address _to,
    uint256 _amount1,
    uint256 _amount2,
    uint256 _amount1Sign,
    uint256 _amount2Sign,
    bytes memory _sign
  ) external payable 
  {
    if (!fiatPayment[msg.sender]) revert onlyApprovedPaymentAddress();

    if (status == Status.whitelist) {
      if (!Verification.verifySignature(signer, _to, _amount1Sign, _amount2Sign, status, _sign))
        revert invalidSignature();
      if (_amount1 + signatureCheckToken1[_sign] > _amount1Sign) revert exceedAllowedToken1Mint();
      if (_amount2 + signatureCheckToken2[_sign] > _amount2Sign) revert exceedAllowedToken2Mint();
      unchecked {
        if ((_amount1 + _amount2) * whitelistPrice > msg.value) revert invalidAmountSend();
      }
    }

    else if (status == Status.publicMint) {
      if (mintPerWallet[_to][1] + _amount1 > maxMintWallet) revert maxMintWalletReachToken1();
      if (mintPerWallet[_to][2] + _amount2 > maxMintWallet) revert maxMintWalletReachToken2();
      unchecked {
        if ((_amount1 + _amount2) * publicPrice > msg.value) revert invalidAmountSend();
      }
    }

    else {
      revert invalidSaleStatus();
    }

    _mintToken1(_to, _amount1);
    _mintToken2(_to, _amount2);
  }

  // SETTER FUNCTIONS

  function setStatus(Status _newStatus) external onlyOwner freezed {
    status = _newStatus;
  }

  function setSigner(address _newSigner) external onlyOwner freezed {
    signer = _newSigner;
  }

  function setFiatPayment(address _newFiatPayment) external onlyOwner {
    fiatPayment[_newFiatPayment] = true;
  }

  function setMaxMintWallet(uint256 _newMaxMintWallet) external onlyOwner freezed {
    maxMintWallet = _newMaxMintWallet;
  }

  function setWhitelistPrice(uint256 _newWhitelistPrice) external onlyOwner freezed {
    whitelistPrice = _newWhitelistPrice;
  }

  function setPublicPrice(uint256 _newPublicPrice) external onlyOwner freezed {
    publicPrice = _newPublicPrice;
  }

  function setDefaultRoyalties(address _recipient, uint96 _feeNumerator) external onlyOwner {
    _setDefaultRoyalty(_recipient, _feeNumerator);
  }

  function freezeContract() external onlyOwner freezed {
    contractFreeze = true;
  }

  function setBaseURI(string calldata _newBaseURI) external onlyOwner freezed {
    baseURI = _newBaseURI;
  }

  function setBaseMediaURICover1(string calldata _newBaseURI) external onlyOwner freezed {
    baseMediaURICover1 = _newBaseURI;
  }

  function setBaseMediaURICover2(string calldata _newBaseURI) external onlyOwner freezed {
    baseMediaURICover2 = _newBaseURI;
  }

  function setSufixURI(string calldata _newSufixURI) external onlyOwner freezed {
    sufixURI = _newSufixURI;
  }

  function addPermanentBaseURI(string calldata prefixURI, string calldata suffixURI) external onlyOwner {
    _addPermanentBaseURI(prefixURI, suffixURI);
  }

  function addPermanentTokenURI(uint256 tokenId, string calldata permanentTokenURI) external onlyOwner {
    _addPermanentTokenURI(tokenId, permanentTokenURI);
  }

  function addPermanentGlobalURI(string calldata permanentGlobalUri) external onlyOwner {
    _addPermanentGlobalURI(permanentGlobalUri);
  }

  // VIEW FUNCTIONS

  function getCurrentStatus() external view returns (Status) {
    return status;
  }

  function getToken1Supply() external view returns (uint256) {
    return token1 - 1;
  }

  function getToken2Supply() external view returns (uint256) {
    return token2 - 101;
  }

  function getAllSupply() external view returns (uint256) {
    return token1 + token2 - 102;
  }

  function getWhitelistPrice() external view returns (uint256) {
    return whitelistPrice;
  }

  function getPublicPrice() external view returns (uint256) {
    return publicPrice;
  }

  function getBalanceOfCover1(address _address) external view returns (uint256) {
    return mintPerWallet[_address][1];
  }

  function getBalanceOfCover2(address _address) external view returns (uint256) {
    return mintPerWallet[_address][2];
  }

  // OVERRIDE FUNCTIONS

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC2981, ERC721, ERC721Enumerable)
    returns(bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    if (!_exists(tokenId)) return "";

    return string(abi.encodePacked(baseURI, tokenId.toString(), sufixURI));
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721PermanentURIs) {
    super._burn(tokenId);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 firstTokenId,
    uint256 batchSize
  ) internal virtual override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
  }

  // INTERNAL FUNCTIONS

  function _mintToken1(address _to, uint256 _amount) internal {
    unchecked {
      if (token1 + _amount > 101) revert maxSupplyToken1Reach();
      for (uint256 i = 0; i < _amount; ++i) {
        _mint(_to, token1);
        _addPermanentTokenURI(token1, baseMediaURICover1);
        ++token1;
      }
      mintPerWallet[_to][1] += _amount;
    }
  }

  function _mintToken2(address _to, uint256 _amount) internal {
    unchecked {
      if (token2 + _amount > 201) revert maxSupplyToken2Reach();
      for (uint256 i = 0; i < _amount; ++i) {
        _mint(_to, token2);
        _addPermanentTokenURI(token2, baseMediaURICover2);
        ++token2;
      }
      mintPerWallet[_to][2] += _amount;
    }
  }
}