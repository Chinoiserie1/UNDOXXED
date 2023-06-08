// SPDX-License-Identifier: MIT
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
  uint256 internal signerPrivateKey;
  address internal signer;

  function setUp() public {
    ownerPrivateKey = 0xA11CE;
    owner = vm.addr(ownerPrivateKey);
    user1PrivateKey = 0xB0B;
    user1 = vm.addr(user1PrivateKey);
    user2PrivateKey = 0xFE55E;
    user2 = vm.addr(user2PrivateKey);
    user3PrivateKey = 0xD1C;
    user3 = vm.addr(user2PrivateKey);
    signerPrivateKey = 0xF10;
    signer = vm.addr(signerPrivateKey);
    vm.startPrank(owner);

    undoxxed = new UNDOXXED();
  }

  function setSale(
    address signer,
    uint256 maxSupply,
    uint256 publicPrice,
    uint256 whitelistPrice,
    uint256 maxPerWalletAllowlist,
    uint256 maxPerWalletWhitelist,
    uint256 maxPerWallet
  )
    public pure returns (Sale memory sale)
  {
    sale.signer = signer;
    sale.maxSupply = maxSupply;
    sale.publicPrice = publicPrice;
    sale.whitelistPrice = whitelistPrice;
    sale.maxPerWalletAllowlist = maxPerWalletAllowlist;
    sale.maxPerWalletWhitelist = maxPerWalletWhitelist;
    sale.maxPerWallet = maxPerWallet;
  }

  function testSetNewSale() public {
    Sale memory sale = setSale(address(signer), 100, 1 ether, 0.5 ether, 0, 0, 1);
    undoxxed.setNewSale(1, sale);
    Sale memory currentSale = undoxxed.getSaleInfo(1);
    require(currentSale.maxSupply == 100, "fail set maxSupply");
    require(currentSale.publicPrice == 1 ether, "fail set public price");
    require(currentSale.whitelistPrice == 0.5 ether, "fail set whitelist price");
    require(currentSale.maxPerWallet == 1, "fail set max per wallet");
    require(currentSale.status == Status.initialized, "fail set status");
    require(currentSale.freezeSale == false, "fail set freeze sale");
    require(currentSale.freezeURI == false, "fail set freeze urif");
  }

  function testSetNewSaleFailNotOwner() public {
    vm.stopPrank();
    vm.startPrank(user1);
    Sale memory sale = setSale(address(signer), 100, 1 ether, 0.5 ether, 0, 0, 1);
    vm.expectRevert();
    undoxxed.setNewSale(1, sale);
  }

  // PUBLIC MINT

  function testPublicMint() public {
    Sale memory sale = setSale(address(signer), 100, 1 ether, 0.5 ether, 0, 0, 1);
    undoxxed.setNewSale(1, sale);
    undoxxed.setSaleStatus(1, Status.publicMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.publicMint{value: 1 ether}(1, 1, "");
    uint256 balance = undoxxed.balanceOf(address(user1), 1);
    require(balance == 1, "fail mint for user1");
    uint256 totalSupply = undoxxed.totalSupply(1);
    require(totalSupply == 1, "fail get totalSupply");
  }

  function testPublicMintFailInsuficientFunds() public {
    Sale memory sale = setSale(address(signer), 100, 1 ether, 0.5 ether, 0, 0, 1);
    undoxxed.setNewSale(1, sale);
    undoxxed.setSaleStatus(1, Status.publicMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    vm.expectRevert(IncorrectValueSend.selector);
    undoxxed.publicMint{value: 0.5 ether}(1, 1, "");
  }

  function testPublicMintFailMintCountExceedMaxPerWallet() public {
    Sale memory sale = setSale(address(signer), 100, 1 ether, 0.5 ether, 0, 0, 1);
    undoxxed.setNewSale(1, sale);
    undoxxed.setSaleStatus(1, Status.publicMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    vm.expectRevert(MaxPerWalletReach.selector);
    undoxxed.publicMint{value: 1 ether}(1, 2, "");
  }

  function testPublicMintFailMintSecondTimeMintCountExceedMaxPerWallet() public {
    Sale memory sale = setSale(address(signer), 100, 1 ether, 0.5 ether, 0, 0, 1);
    undoxxed.setNewSale(1, sale);
    undoxxed.setSaleStatus(1, Status.publicMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.publicMint{value: 1 ether}(1, 1, "");
    vm.expectRevert(MaxPerWalletReach.selector);
    undoxxed.publicMint{value: 1 ether}(1, 1, "");
  }

  function testPublicMintMintAllSupply() public {
    Sale memory sale = setSale(address(signer), 10, 1 ether, 0.5 ether, 0, 0, 10);
    undoxxed.setNewSale(1, sale);
    undoxxed.setSaleStatus(1, Status.publicMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.publicMint{value: 10 ether}(1, 10, "");
  }

  // URI

  function testURI() public {
    string memory uri = "TheNewURI/";
    undoxxed.setURI(1, uri);
    string memory currentURI = undoxxed.uri(1);
    require(keccak256(abi.encode(uri)) == keccak256(abi.encode(currentURI)), "fail URI");
  }

  function testURIMultipleTokenId() public {
    string memory uri = "TheNewURI/";
    undoxxed.setURI(1, uri);
    string memory currentURI = undoxxed.uri(1);
    require(keccak256(abi.encode(uri)) == keccak256(abi.encode(currentURI)), "fail URI");
    uri = "TheSecondNewURI/123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    undoxxed.setURI(2, uri);
    currentURI = undoxxed.uri(2);
    require(keccak256(abi.encode(uri)) == keccak256(abi.encode(currentURI)), "fail URI 2");
  }
}
