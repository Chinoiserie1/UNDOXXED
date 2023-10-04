// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../../src/ERC721/UNDOXXED.sol";
import "../../src/ERC721/verification/Verification.sol";

contract UNDOXXEDTest is Test {
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
    undoxxed.setSigner(signer);
  }

  function sign(address _to, uint256 _amount1, uint256 _amount2, Status _status) public view returns(bytes memory) {
    bytes32 messaggeHash = Verification.getMessageHash(_to, _amount1, _amount2, _status);
    bytes32 finalHash = Verification.getEthSignedMessageHash(messaggeHash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, finalHash);
    bytes memory signature = abi.encodePacked(r, s, v);
    return signature;
  }

  function testStatus() public view {
    require(undoxxed.getCurrentStatus() == Status.notInitialized, "fail init status");
  }

  // test allowlist
  function testAllowlistMint() public {
    undoxxed.setStatus(Status.allowlist);
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(user1, 5, 5, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 10, "fail mint in allowlist");
  }

  function testAllowlistMintLowerThanAllowed() public {
    undoxxed.setStatus(Status.allowlist);
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(user1, 2, 2, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 4, "fail mint in allowlist");
  }

  // test setter

  function testSetStatus() public {
    undoxxed.setStatus(Status.allowlist);
    require(undoxxed.getCurrentStatus() == Status.allowlist, "fail set status");
  }

  function testSetStatusFailNotOwner() public {
    vm.stopPrank();
    vm.prank(user1);
    vm.expectRevert();
    undoxxed.setStatus(Status.allowlist);
  }
}