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

  event SetSale(uint256 tokenId, Sale saleInfo);
  event FreezeSale(uint256 tokenId);

  constructor() ERC1155("UNDOXXED", "UNDX", "") {}

  function setSale(uint256 _tokenId, Sale calldata _saleInfo) external onlyOwner {
    if (saleInfo[_tokenId].freeze) revert SaleFreeze();
    saleInfo[_tokenId] = _saleInfo;
    emit SetSale(_tokenId, _saleInfo);
  }

  function freezeSale(uint256 _tokenId) external onlyOwner {
    if(saleInfo[_tokenId].status == Status.notInitialised) revert SaleNotInitialised();
    saleInfo[_tokenId].freeze = true;
    emit FreezeSale(_tokenId);
  }

  function publicMint(uint256 _tokenId, uint256 _amountMint, bytes calldata data) external payable {
    if(saleInfo[_tokenId].status != Status.started) revert SaleNotStarted();
    if(_amountMint + mintCount[msg.sender][_tokenId] > saleInfo[_tokenId].maxPerWallet) revert MaxPerWalletReach();
    if(msg.value < saleInfo[_tokenId].publicPrice) revert IncorrectValueSend();

    _mint(msg.sender, _tokenId, _amountMint, data);

    unchecked {
      mintCount[msg.sender][_tokenId] += _amountMint;
    }
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
