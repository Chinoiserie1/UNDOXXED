// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/UNDOXXED.sol";
import "../src/IUNDOXXED.sol";

contract CounterTest is Test {
  UNDOXXED public undoxxed;

  uint256 internal ownerPrivateKey;
  address internal owner;
  uint256 internal user1PrivateKey;
  address internal user1;
  uint256 internal user2PrivateKey;
  address internal user2;
  int256 internal user3PrivateKey;
  address internal user3;

  function setUp() public {
    ownerPrivateKey = 0xA11CE;
    owner = vm.addr(ownerPrivateKey);
    user1PrivateKey = 0xB0B;
    user1 = vm.addr(user1PrivateKey);
    user2PrivateKey = 0xFE55E;
    user2 = vm.addr(user2PrivateKey);
    user3PrivateKey = 0xD1C;
    user3 = vm.addr(user2PrivateKey);
    vm.startPrank(owner);

    undoxxed = new UNDOXXED();
  }

  function setSale(
    uint256 maxSupply,
    uint256 publicPrice,
    uint256 whitelistPrice,
    uint256 maxPerWallet
  )
    public pure returns (Sale memory sale)
  {
    sale.maxSupply = maxSupply;
    sale.publicPrice = publicPrice;
    sale.whitelistPrice = whitelistPrice;
    sale.maxPerWallet = maxPerWallet;
  }

  function testSetNewSale() public {
    Sale memory sale = setSale(100, 1 ether, 0.5 ether, 1);
    undoxxed.setNewSale(1, sale);
    Sale memory currentSale = undoxxed.getSaleInfo(1);
    require(currentSale.maxSupply == 100, "fail set maxSupply");
    require(currentSale.publicPrice == 1 ether, "fail set public price");
    require(currentSale.whitelistPrice == 0.5 ether, "fail set whitelist price");
    require(currentSale.maxPerWallet == 1, "fail set max per wallet");
    require(currentSale.status == Status.initialized, "fail set status");
    require(currentSale.freeze == false, "fail set freeze");
  }

  function testSetNewSaleFailNotOwner() public {
    vm.stopPrank();
    vm.startPrank(user1);
    Sale memory sale = setSale(100, 1 ether, 0.5 ether, 1);
    vm.expectRevert();
    undoxxed.setNewSale(1, sale);
  }

  function g() public {
    Sale memory sale = setSale(100, 1 ether, 0.5 ether, 1);
    undoxxed.setNewSale(1, sale);
    undoxxed.setSaleStatus(1, Status.started);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.publicMint{value: 1 ether}(1, 1, "");
    uint256 balance = undoxxed.balanceOf(address(user1), 1);
    require(balance == 1, "fail mint for user1");
  }
}
