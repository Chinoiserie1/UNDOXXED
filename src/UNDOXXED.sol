// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/Assembly/src/access/Ownable.sol";
import "lib/Assembly/src/tokens/ERC1155/extensions/ERC1155URIStorage.sol";
import "lib/Assembly/src/tokens/ERC1155/extensions/ERC1155Supply.sol";

// import "lib/openzeppelin-contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

import "./IUNDOXXED.sol";

contract UNDOXXED is ERC1155URIStorage, ERC1155Supply, Ownable {
  mapping(uint256 => Sale) private saleInfo;
  // address who mint => tokenId => mint count
  mapping(address => mapping(uint256 => uint256)) private mintCount;

  event SetNewSale(uint256 tokenId, Sale newSale);
  event SetSaleMaxPerWallet(uint256 tokenId, uint256 newMaxPerWallet);
  event SetSaleMaxSupply(uint256 tokenId, uint256 newMaxSupply);
  event SetSalePublicPrice(uint256 tokenId, uint256 newPublicPrice);
  event SetSaleWhitelistPrice(uint256 tokenId, uint256 newWhitelistPrice);
  event SetSaleStatus(uint256 _tokenId, Status newStatus);
  event FreezeSale(uint256 tokenId);
  event FreezeURI(uint256 tokenId);

  constructor() ERC1155("UNDOXXED", "UNDX", "") {}

  function publicMint(uint256 _tokenId, uint256 _amountMint, bytes calldata data) external payable {
    if (saleInfo[_tokenId].status != Status.publicMint) revert SaleNotStarted();
    if (_amountMint + mintCount[msg.sender][_tokenId] > saleInfo[_tokenId].maxPerWallet) revert MaxPerWalletReach();
    if (msg.value * _amountMint < saleInfo[_tokenId].publicPrice * _amountMint) revert IncorrectValueSend();

    _mint(msg.sender, _tokenId, _amountMint, data);

    unchecked {
      mintCount[msg.sender][_tokenId] += _amountMint;
    }
  }

  // VIEW FUNCTIONS
  function getSaleInfo(uint256 _tokenId) external view returns (Sale memory sale) {
    return saleInfo[_tokenId];
  }

  // ONLY OWNER FUNCTIONS
  function setNewSale(uint256 _tokenId, Sale memory _newsale) external onlyOwner {
    if (saleInfo[_tokenId].status != Status.notInitialized) revert SaleAlreadyInitialized();
    saleInfo[_tokenId] = _newsale;
    saleInfo[_tokenId].status = Status.initialized;
    emit SetNewSale(_tokenId, _newsale);
  }

  function setSaleMaxSupply(uint256 _tokenId, uint256 _maxSupply) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    if (saleInfo[_tokenId].freezeSale) revert SaleFreeze();
    saleInfo[_tokenId].maxSupply = _maxSupply;
    emit SetSaleMaxSupply(_tokenId, _maxSupply);
  }

  function setSaleMaxPerWallet(uint256 _tokenId, uint256 _maxPerWallet) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    if (saleInfo[_tokenId].freezeSale) revert SaleFreeze();
    saleInfo[_tokenId].maxPerWallet = _maxPerWallet;
    emit SetSaleMaxPerWallet(_tokenId, _maxPerWallet);
  }

  function setSalePublicPrice(uint256 _tokenId, uint256 _publicPrice) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    if (saleInfo[_tokenId].freezeSale) revert SaleFreeze();
    saleInfo[_tokenId].publicPrice = _publicPrice;
    emit SetSalePublicPrice(_tokenId, _publicPrice);
  }

  function setSaleWhitelistPrice(uint256 _tokenId, uint256 _whitelistPrice) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    if (saleInfo[_tokenId].freezeSale) revert SaleFreeze();
    saleInfo[_tokenId].whitelistPrice = _whitelistPrice;
    emit SetSaleWhitelistPrice(_tokenId, _whitelistPrice);
  }

  function setSaleStatus(uint256 _tokenId, Status newStatus) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    saleInfo[_tokenId].status = newStatus;
    emit SetSaleStatus(_tokenId, newStatus);
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

  function freezeURI(uint256 _tokenId) external onlyOwner {
    if (saleInfo[_tokenId].status == Status.notInitialized) revert SaleNotInitialized();
    saleInfo[_tokenId].freezeURI = true;
    emit FreezeURI(_tokenId);
  }

  function setURI(uint256 _tokenId, string calldata _tokenURI) external onlyOwner {
    if (saleInfo[_tokenId].freezeURI) revert URIFreeze();
    _setURI(_tokenId, _tokenURI);
    emit URI(_tokenURI, _tokenId);
  }

  // OVERRIDE FUNCTIONS
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
