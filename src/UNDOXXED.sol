// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/Assembly/src/access/Ownable.sol";
// import "lib/Assembly/src/tokens/ERC1155/extensions/ERC1155URIStorage.sol";
// import "lib/Assembly/src/tokens/ERC1155/extensions/ERC1155Supply.sol";

import "lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import "./IUNDOXXED.sol";
import "./verification/Verification.sol";

/**
 * @title UNDOXXED
 * @author chixx.eth
 * @notice ERC1155 with extensions URIStorage, Supply, Royalties and Ownable
 */
contract UNDOXXED is ERC1155URIStorage, ERC1155Supply, ERC2981, Ownable {
  mapping(uint256 => Sale) private saleInfo;

  // address who mint => tokenId => mint count
  mapping(address => mapping(uint256 => uint256)) private mintCount;
  mapping(address => mapping(uint256 => uint256)) private allowlistMintCount;
  mapping(address => mapping(uint256 => uint256)) private whitelistMintCount;

  event SetNewSale(uint256 tokenId, Sale newSale);
  event SetSaleMaxPerWalletAllowlist(uint256 tokenId, uint256 newMaxPerWallet);
  event SetSaleMaxPerWalletWhitelist(uint256 tokenId, uint256 newMaxPerWallet);
  event SetSaleMaxPerWallet(uint256 tokenId, uint256 newMaxPerWallet);
  event SetSaleMaxSupply(uint256 tokenId, uint256 newMaxSupply);
  event SetSalePublicPrice(uint256 tokenId, uint256 newPublicPrice);
  event SetSaleWhitelistPrice(uint256 tokenId, uint256 newWhitelistPrice);
  event SetSaleStatus(uint256 _tokenId, Status newStatus);
  event SetSaleSigner(uint256 tokenId, address newSigner);
  event FreezeSale(uint256 tokenId);
  event FreezeURI(uint256 tokenId);

  constructor() ERC1155("") {
    _setDefaultRoyalty(msg.sender, 500);
  }

  /**
   * @notice verify signature
   */
  modifier verify(address _to, uint256 _tokenId, uint256 _amount, Status _status, bytes memory _sign) {
    if (!Verification.verifySignature(saleInfo[_tokenId].signer, _to, _amount, _status, _sign)) revert invalidSignature();
    _;
  }

  /**
   * @notice function for mint in the allowlist status
   * @param _tokenId tokenId of the sale / id of the nft
   * @param _amountMint amount the user want to mint
   * @param _amountSign amount given by the signer to the user to mint
   * @param signature the signature of the signer
   * @param data extra data { not needed here }
   */
  function allowlistMint(
    uint256 _tokenId,
    uint256 _amountMint,
    uint256 _amountSign,
    bytes calldata signature,
    bytes calldata data
  ) 
    external verify(msg.sender, _tokenId, _amountSign, Status.allowlist, signature)
  {
    if (saleInfo[_tokenId].status != Status.allowlist) revert AllowlistNotStarted();
    if (_amountMint + totalSupply(_tokenId) > saleInfo[_tokenId].maxSupply) revert MaxSupplyReach();
    if (saleInfo[_tokenId].maxPerWalletAllowlist == 0) {
      if (mintCount[msg.sender][_tokenId] + _amountMint > saleInfo[_tokenId].maxPerWallet) revert MaxPerWalletReach();
      unchecked { mintCount[msg.sender][_tokenId] += _amountMint; }
    } else {
      if (allowlistMintCount[msg.sender][_tokenId] + _amountMint > saleInfo[_tokenId].maxPerWalletAllowlist) revert MaxPerWalletReach();
      unchecked { allowlistMintCount[msg.sender][_tokenId] += _amountMint; }
    }

    _mint(msg.sender, _tokenId, _amountMint, data);
  }

  /**
   * @notice function for mint in the whitelist status
   * @param _tokenId tokenId of the sale / id of the nft
   * @param _amountMint amount the user want to mint
   * @param _amountSign amount given by the signer to the user to mint
   * @param signature the signature of the signer
   * @param data extra data { not needed here }
   */
  function whitelistMint(
    uint256 _tokenId,
    uint256 _amountMint,
    uint256 _amountSign,
    bytes calldata signature,
    bytes calldata data
  )
    external payable verify(msg.sender, _tokenId, _amountSign, Status.whitelist, signature)
  {
    if (saleInfo[_tokenId].status != Status.whitelist) revert WhitelistSaleNotStarted();
    if (msg.value * _amountMint < saleInfo[_tokenId].whitelistPrice * _amountMint) revert IncorrectValueSend();
    if (_amountMint + totalSupply(_tokenId) > saleInfo[_tokenId].maxSupply) revert MaxSupplyReach();
    if (saleInfo[_tokenId].maxPerWalletWhitelist == 0) {
      if (mintCount[msg.sender][_tokenId] + _amountMint > saleInfo[_tokenId].maxPerWallet) revert MaxPerWalletReach();
      unchecked { mintCount[msg.sender][_tokenId] += _amountMint; }
    } else {
      if (whitelistMintCount[msg.sender][_tokenId] + _amountMint > saleInfo[_tokenId].maxPerWalletWhitelist) revert MaxPerWalletReach();
      unchecked { whitelistMintCount[msg.sender][_tokenId] += _amountMint; }
    }

    _mint(msg.sender, _tokenId, _amountMint, data);
  }

  /**
   * @notice function for mint in the public status
   * @param _tokenId tokenId of the sale / id of the nft
   * @param _amountMint amount the user want to mint
   * @param data extra data { not needed here }
   */
  function publicMint(uint256 _tokenId, uint256 _amountMint, bytes calldata data) external payable {
    if (saleInfo[_tokenId].status != Status.publicMint) revert PublicSaleNotStarted();
    if (_amountMint + mintCount[msg.sender][_tokenId] > saleInfo[_tokenId].maxPerWallet) revert MaxPerWalletReach();
    if (msg.value * _amountMint < saleInfo[_tokenId].publicPrice * _amountMint) revert IncorrectValueSend();
    if (_amountMint + totalSupply(_tokenId) > saleInfo[_tokenId].maxSupply) revert MaxSupplyReach();

    _mint(msg.sender, _tokenId, _amountMint, data);

    unchecked {
      mintCount[msg.sender][_tokenId] += _amountMint;
    }
  }

  // VIEW FUNCTIONS

  function name() external pure returns(string memory) {
    return "UNDOXXED";
  }

  function symbol() external pure returns(string memory) {
    return "UNDX";
  }

  /**
   * @notice return info of the sale
   * @param _tokenId tokenId of the sale / id of the nft
   */
  function getSaleInfo(uint256 _tokenId) external view returns (Sale memory sale) {
    return saleInfo[_tokenId];
  }

  // ONLY OWNER FUNCTIONS

  /**
   * @notice setNewSale aim to create a new sale
   * @param _tokenId the tokenId of the new sale
   * @param _newsale see { IUNDOXXED.sol }
   * @dev 
   */
  function setNewSale(uint256 _tokenId, Sale memory _newsale) external onlyOwner {
    if (saleInfo[_tokenId].status != Status.notInitialized) revert SaleAlreadyInitialized();
    saleInfo[_tokenId] = _newsale;
    saleInfo[_tokenId].status = Status.initialized;
    emit SetNewSale(_tokenId, _newsale);
  }

  /**
   * @notice set max supply of a specific sale
   * @param _tokenId tokenId of the sale
   * @param _maxSupply the new max supply
   * @dev sale must be initialized and not freeze
   */
  function setSaleMaxSupply(uint256 _tokenId, uint256 _maxSupply) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    if (saleInfo[_tokenId].freezeSale) revert SaleFreeze();
    saleInfo[_tokenId].maxSupply = _maxSupply;
    emit SetSaleMaxSupply(_tokenId, _maxSupply);
  }

  /**
   * @notice set max per wallet a user can mint during allowlist
   * @param _tokenId tokenId of the sale
   * @param _maxPerWallet the new max per wallet a user can mint
   * @dev sale must be initialized and not freeze
   *      if set to 0 the max is max per wallet { saleInfo[id].maxPerWallet }
   */
  function setSaleMaxPerWalletAllowlist(uint256 _tokenId, uint256 _maxPerWallet) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    if (saleInfo[_tokenId].freezeSale) revert SaleFreeze();
    saleInfo[_tokenId].maxPerWalletAllowlist = _maxPerWallet;
    emit SetSaleMaxPerWalletAllowlist(_tokenId, _maxPerWallet);
  }

  /**
   * @notice set max per wallet for whitelist
   * @param _tokenId tokenId of the sale
   * @param _maxPerWallet the new max per wallet a user can mint
   * @dev sale must be initialized and not freeze
   *      if set to 0 the max is max per wallet { saleInfo[id].maxPerWallet }
   */
  function setSaleMaxPerWalletWhitelist(uint256 _tokenId, uint256 _maxPerWallet) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    if (saleInfo[_tokenId].freezeSale) revert SaleFreeze();
    saleInfo[_tokenId].maxPerWalletWhitelist = _maxPerWallet;
    emit SetSaleMaxPerWalletWhitelist(_tokenId, _maxPerWallet);
  }

  /**
   * @notice set max per wallet
   * @param _tokenId tokenId of the sale
   * @param _maxPerWallet the new max per wallet a user can mint
   * @dev sale must be initialized and not freeze
   */
  function setSaleMaxPerWallet(uint256 _tokenId, uint256 _maxPerWallet) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    if (saleInfo[_tokenId].freezeSale) revert SaleFreeze();
    saleInfo[_tokenId].maxPerWallet = _maxPerWallet;
    emit SetSaleMaxPerWallet(_tokenId, _maxPerWallet);
  }

   /**
   * @notice set the price for public mint
   * @param _tokenId tokenId of the sale
   * @param _publicPrice the new price for public mint
   * @dev sale must be initialized and not freeze
   */
  function setSalePublicPrice(uint256 _tokenId, uint256 _publicPrice) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    if (saleInfo[_tokenId].freezeSale) revert SaleFreeze();
    saleInfo[_tokenId].publicPrice = _publicPrice;
    emit SetSalePublicPrice(_tokenId, _publicPrice);
  }

  /**
   * @notice set the price for whitelist mint
   * @param _tokenId tokenId of the sale
   * @param _whitelistPrice the new price for whitelist mint
   * @dev sale must be initialized and not freeze
   */
  function setSaleWhitelistPrice(uint256 _tokenId, uint256 _whitelistPrice) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    if (saleInfo[_tokenId].freezeSale) revert SaleFreeze();
    saleInfo[_tokenId].whitelistPrice = _whitelistPrice;
    emit SetSaleWhitelistPrice(_tokenId, _whitelistPrice);
  }

  /**
   * @notice set status for a specific sale
   * @param _tokenId tokenId of the sale
   * @param newStatus the new status of the sale
   * @dev sale must be initialized
   */
  function setSaleStatus(uint256 _tokenId, Status newStatus) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    saleInfo[_tokenId].status = newStatus;
    emit SetSaleStatus(_tokenId, newStatus);
  }

  /**
   * @notice set a new signer for signature
   * @param _tokenId tokenId of the sale
   * @param newSigner address of the new signer
   * @dev sale must be initialized
   *      if a signer change all precedent signature will be invalid
   */
  function setSaleSigner(uint256 _tokenId, address newSigner) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    saleInfo[_tokenId].signer = newSigner;
    emit SetSaleSigner(_tokenId, newSigner);
  }

  /**
   * @notice freeze the sale for update maxSupply, publicPrice, whitelistPrice, maxPerWallet
   * @param _tokenId the id of the sale to freeze
   */
  function freezeSale(uint256 _tokenId) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    saleInfo[_tokenId].freezeSale = true;
    emit FreezeSale(_tokenId);
  }

  /**
   * @notice freeze the URI of a specific tokenId
   * @param _tokenId tokenId of the sale
   */
  function freezeURI(uint256 _tokenId) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    saleInfo[_tokenId].freezeURI = true;
    emit FreezeURI(_tokenId);
  }

  /**
   * @notice set new URI for a specific tokenId
   * @param _tokenId tokenId of the sale
   * @param _tokenURI the new URI
   * @dev URI must not be freeze
   */
  function setURI(uint256 _tokenId, string calldata _tokenURI) external onlyOwner {
    if (saleInfo[_tokenId].freezeURI) revert URIFreeze();
    _setURI(_tokenId, _tokenURI);
    emit URI(_tokenURI, _tokenId);
  }

  function setDefaultRoyalties(address _recipient, uint96 _feeNumerator) external onlyOwner {
    _setDefaultRoyalty(_recipient, _feeNumerator);
  }

  // OVERRIDE FUNCTIONS
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC2981) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function uri(uint256 tokenId) public view virtual override(ERC1155, ERC1155URIStorage) returns (string memory) {
    return super.uri(tokenId);
  }

  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) internal virtual override(ERC1155, ERC1155Supply) {
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
  }
}
