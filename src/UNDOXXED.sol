// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "lib/Assembly/src/access/Ownable.sol";
import "lib/Assembly/src/tokens/ERC1155/extensions/ERC1155URIStorage.sol";
import "lib/Assembly/src/tokens/ERC1155/extensions/ERC1155Supply.sol";

error SaleFreeze();
error SaleNotInitialised();
error SaleNotStarted();
error MaxPerWalletReach();
error IncorrectValueSend();

contract UNDOXXED is ERC1155URIStorage, ERC1155Supply, Ownable {
  struct Sale {
    uint256 maxSupply;
    uint256 publicPrice;
    uint256 whitelistPrice;
    uint256 maxPerWallet;
    Status status;
    bool freeze;
  }

  enum Status {
    notInitialised,
    started,
    finished,
    paused
  }

  mapping(uint256 => Sale) private saleInfo;
  // address who mint => tokenId => mint count
  mapping(address => mapping(uint256 => uint256)) private mintCount;

  event SetSaleMaxPerWallet(uint256 tokenId, uint256 newMaxPerWallet);
  event SetSaleMaxSupply(uint256 tokenId, uint256 newMaxSupply);
  event SetSalePublicPrice(uint256 tokenId, uint256 newPublicPrice);
  event SetSaleWhitelistPrice(uint256 tokenId, uint256 newWhitelistPrice);
  event FreezeSale(uint256 tokenId);

  constructor() ERC1155("UNDOXXED", "UNDX", "") {}

  function publicMint(uint256 _tokenId, uint256 _amountMint, bytes calldata data) external payable {
    if(saleInfo[_tokenId].status != Status.started) revert SaleNotStarted();
    if(_amountMint + mintCount[msg.sender][_tokenId] > saleInfo[_tokenId].maxPerWallet) revert MaxPerWalletReach();
    if(msg.value * _amountMint < saleInfo[_tokenId].publicPrice * _amountMint) revert IncorrectValueSend();

    _mint(msg.sender, _tokenId, _amountMint, data);

    unchecked {
      mintCount[msg.sender][_tokenId] += _amountMint;
    }
  }

  // ONLY OWNER
  function setSaleMaxSupply(uint256 _tokenId, uint256 _maxSupply) external onlyOwner {
    if (saleInfo[_tokenId].freeze) revert SaleFreeze();
    saleInfo[_tokenId].maxSupply = _maxSupply;
    emit SetSaleMaxSupply(_tokenId, _maxSupply);
  }

  function setSaleMaxPerWallet(uint256 _tokenId, uint256 _maxPerWallet) external onlyOwner {
    if (saleInfo[_tokenId].freeze) revert SaleFreeze();
    saleInfo[_tokenId].maxPerWallet = _maxPerWallet;
    emit SetSaleMaxPerWallet(_tokenId, _maxPerWallet);
  }

  function setSalePublicPrice(uint256 _tokenId, uint256 _publicPrice) external onlyOwner {
    if (saleInfo[_tokenId].freeze) revert SaleFreeze();
    saleInfo[_tokenId].publicPrice = _publicPrice;
    emit SetSalePublicPrice(_tokenId, _publicPrice);
  }

  function setSaleWhitelistPrice(uint256 _tokenId, uint256 _whitelistPrice) external onlyOwner {
    if (saleInfo[_tokenId].freeze) revert SaleFreeze();
    saleInfo[_tokenId].whitelistPrice = _whitelistPrice;
    emit SetSaleWhitelistPrice(_tokenId, _whitelistPrice);
  }

  /**
   * @notice freeze the sale for update maxSupply, publicPrice, whitelistPrice, maxPerWallet
   * @param _tokenId the id of the sale
   */
  function freezeSale(uint256 _tokenId) external onlyOwner {
    if(saleInfo[_tokenId].status == Status.notInitialised) revert SaleNotInitialised();
    saleInfo[_tokenId].freeze = true;
    emit FreezeSale(_tokenId);
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
