// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/forge-std/src/Test.sol";

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
  uint256 internal user3PrivateKey;
  address internal user3;
  uint256 internal signerPrivateKey;
  address internal signer;

  uint256 internal maxSupply = 300;
  uint256 internal maxSupplyToken1 = 150;
  uint256 internal maxSupplyToken2 = 150;

  uint256 internal privateWhitelistCover1 = 10;
  uint256 internal privateWhitelistCover2 = 10;

  uint256 internal whitelistPrice;
  uint256 internal publicPrice;

  function setUp() public {
    ownerPrivateKey = 0xA11CE;
    owner = vm.addr(ownerPrivateKey);
    user1PrivateKey = 0xB0B;
    user1 = vm.addr(user1PrivateKey);
    user2PrivateKey = 0xFE55E;
    user2 = vm.addr(user2PrivateKey);
    user3PrivateKey = 0xD1C;
    user3 = vm.addr(user3PrivateKey);
    signerPrivateKey = 0xF10;
    signer = vm.addr(signerPrivateKey);
    vm.startPrank(owner);

    undoxxed = new UNDOXXED();
    undoxxed.setSigner(signer);
    whitelistPrice = undoxxed.getWhitelistPrice();
    publicPrice = undoxxed.getPublicPrice();
  }

  function sign(address _to, uint256 _amount1, uint256 _amount2, Status _status) public view returns(bytes memory) {
    bytes32 messaggeHash = Verification.getMessageHash(_to, _amount1, _amount2, _status);
    bytes32 finalHash = Verification.getEthSignedMessageHash(messaggeHash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, finalHash);
    bytes memory signature = abi.encodePacked(r, s, v);
    return signature;
  }

  function testGetMessageHash() public view {
    uint256 pk = vm.envUint("PRIVATE_KEY");
    bytes32 messageHash = Verification.getMessageHash(0x90D41fA17a8dF96E7dff80227b4FC7d208dFd026, 1, 0, Status.privateWhitelist);
    bytes32 finalHash = Verification.getEthSignedMessageHash(messageHash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, finalHash);
    bytes memory signature = abi.encodePacked(r, s, v);
    console.logBytes(signature);
  }

  function testStatus() public view {
    require(undoxxed.getCurrentStatus() == Status.notInitialized, "fail init status");
  }

  // test deploy

  function testDeployContract() public {
    UNDOXXED undoxxedDeploy = new UNDOXXED();
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

  function testAllowlistMint1Copies() public {
    undoxxed.setStatus(Status.allowlist);
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(user1, 1, 0, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 1, "fail mint in allowlist");
  }

  function testAllowlistMint20Copies() public {
    undoxxed.setStatus(Status.allowlist);
    bytes memory signature = sign(user1, 10, 10, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(user1, 10, 10, 10, 10, signature);
    require(undoxxed.balanceOf(user1) == 20, "fail mint in allowlist");
  }

  function testAllowlistMintFuzzAmountMint(uint256 _amount1, uint256 _amount2) public {
    undoxxed.setStatus(Status.allowlist);
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    if (_amount1 < 6 && _amount2 < 6) {
      undoxxed.allowlistMint(user1, _amount1, _amount2, 5, 5, signature);
      require(undoxxed.balanceOf(user1) == _amount1 + _amount2, "fail mint in allowlist");
    } else {
      if (_amount1 > 5 ) {
        vm.expectRevert(exceedAllowedToken1Mint.selector);
      } else if (_amount2 > 5 ) {
        vm.expectRevert(exceedAllowedToken2Mint.selector);
      }
      undoxxed.allowlistMint(user1, _amount1, _amount2, 5, 5, signature);
    }
  }

  function testAllowlistMintLowerThanAllowed() public {
    undoxxed.setStatus(Status.allowlist);
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(user1, 2, 2, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 4, "fail mint in allowlist");
  }

  function testAllowlistMintAllSupply() public {
    undoxxed.setStatus(Status.allowlist);
    undoxxed.setMaxMintWallet(250);
    bytes memory signature = sign(user1, 250, 250, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(user1, maxSupplyToken1, maxSupplyToken2, 250, 250, signature);
    require(undoxxed.balanceOf(user1) == maxSupply, "fail mint all supply in allowlist");
  }

  function testAllowlistMintAllSupplyMultipleCall() public {
    undoxxed.setStatus(Status.allowlist);
    undoxxed.setMaxMintWallet(250);
    bytes memory signature = sign(user1, 250, 250, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(user1, maxSupplyToken1 - 1, maxSupplyToken2 - 1, 250, 250, signature);
    require(undoxxed.balanceOf(user1) == maxSupply - 2, "fail mint all supply in allowlist");
    undoxxed.allowlistMint(user1, 1, 1, 250, 250, signature);
    require(undoxxed.balanceOf(user1) == maxSupply, "fail mint all supply in allowlist");
  }

  function testAllowlistShouldFailWrongStatus() public {
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(invalidSaleStatus.selector);
    undoxxed.allowlistMint(user1, 5, 5, 5, 5, signature);
  }

  function testAllowlistMintGreaterThanAllowedShouldFail() public {
    undoxxed.setStatus(Status.allowlist);
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(exceedAllowedToken1Mint.selector);
    undoxxed.allowlistMint(user1, 6, 6, 5, 5, signature);
  }

  function testAllowlistMintGreaterThanAllowedShouldFailMultipleCall() public {
    undoxxed.setStatus(Status.allowlist);
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(user1, 2, 2, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 4, "fail mint in allowlist");
    vm.expectRevert(exceedAllowedToken1Mint.selector);
    undoxxed.allowlistMint(user1, 4, 3, 5, 5, signature);
  }

  function testAllowlistMintMoreThanAllSupplyShouldFail() public {
    undoxxed.setStatus(Status.allowlist);
    undoxxed.setMaxMintWallet(300);
    bytes memory signature = sign(user1, 250, 250, Status.allowlist);
    bytes memory signature2 = sign(user2, 250, 250, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(user1, maxSupplyToken1, maxSupplyToken2, 250, 250, signature);
    require(undoxxed.balanceOf(user1) == maxSupply, "fail mint all supply in allowlist");
    vm.stopPrank();
    vm.startPrank(user2);
    vm.expectRevert(maxSupplyToken1Reach.selector);
    undoxxed.allowlistMint(user2, 1, 1, 250, 250, signature2);
  }

  // test whitelist

  function testWhitelistMint1Copies() public {
    undoxxed.setStatus(Status.whitelist);
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.whitelistMint{value: whitelistPrice * 1}(user1, 1, 0, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 1, "fail mint in whitelist");
  }

  function testWhitelistMintShouldSuccess() public {
    undoxxed.setStatus(Status.whitelist);
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.whitelistMint{value: 1 ether}(user1, 5, 5, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 10, "fail mint in whitelist");
  }

  function testWhitelistMintShouldSuccessPublicPhase() public {
    undoxxed.setStatus(Status.publicMint);
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.whitelistMint{value: 1 ether}(user1, 5, 5, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 10, "fail mint in whitelist");
  }

  function testWhitelistMintFuzz(uint256 _amount1, uint256 _amount2) public {
    vm.deal(user1, uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
    undoxxed.setStatus(Status.whitelist);
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    uint256 amountToSend;
    unchecked {
      amountToSend = 0.1 ether * (_amount1 + _amount2);
    }
    if (_amount1 < 6 && _amount2 < 6) {
      undoxxed.whitelistMint{value: amountToSend}(user1, _amount1, _amount2, 5, 5, signature);
      require(undoxxed.balanceOf(user1) == _amount1 + _amount2, "fail mint in whitelist");
    } else {
      if (_amount1 > 5) {
        vm.expectRevert();
      } else if (_amount2 > 5) {
        vm.expectRevert();
      }
      undoxxed.whitelistMint{value: amountToSend}(user1, _amount1, _amount2, 5, 5, signature);
    }
  }

  function testWhitelistMintShouldSuccessMultipleCall() public {
    undoxxed.setStatus(Status.whitelist);
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.whitelistMint{value: 0.2 ether}(user1, 2, 0, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 2, "fail mint in whitelist");
    undoxxed.whitelistMint{value: 0.8 ether}(user1, 3, 5, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 10, "fail mint in whitelist in second call");
  }

  function testWhitelistMintShouldFailInvalidUser() public {
    undoxxed.setStatus(Status.whitelist);
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user2);
    vm.deal(user2, 100 ether);
    vm.expectRevert(invalidSignature.selector);
    undoxxed.whitelistMint{value: 1 ether}(user2, 5, 5, 5, 5, signature);
  }

  function testWhitelistMintShouldFailInvalidAmountSend() public {
    undoxxed.setStatus(Status.whitelist);
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    vm.expectRevert(invalidAmountSend.selector);
    undoxxed.whitelistMint{value: whitelistPrice * 9}(user1, 5, 5, 5, 5, signature);
  }

  // test mint

  function testPublicMintShouldSuccess() public {
    undoxxed.setStatus(Status.publicMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.mint{value: publicPrice * 20}(user1, 10, 10);
    require(undoxxed.balanceOf(user1) == 20, "fail mint in public");
  }

  function testPublicMIntShouldSuccessMultipleCall() public {
    undoxxed.setStatus(Status.publicMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.mint{value: publicPrice * 10}(user1, 5, 5);
    require(undoxxed.balanceOf(user1) == 10, "fail mint in public");
    undoxxed.mint{value: publicPrice * 10}(user1, 5, 5);
    require(undoxxed.balanceOf(user1) == 20, "fail mint in public");
  }

  function testPublicMintShouldRevertInvalidAmountSend() public {
    undoxxed.setStatus(Status.publicMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    vm.expectRevert(invalidAmountSend.selector);
    undoxxed.mint{value: publicPrice * 19}(user1, 10, 10);
  }

  function testPublicMintShouldRevertMintMoreThamAllowed() public {
    undoxxed.setStatus(Status.publicMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    vm.expectRevert(maxMintWalletReachToken1.selector);
    undoxxed.mint{value: publicPrice * 21}(user1, 11, 10);
  }

  // test fiat payment

  function testFiatPaymentMintWhitelist() public {
    undoxxed.setStatus(Status.whitelist);
    undoxxed.setFiatPayment(user1);
    vm.deal(user1, 100 ether);
    bytes memory signature = sign(user2, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.fiatPaymentMint{value : whitelistPrice * 10}(user2, 5, 5, 5, 5, signature);
    require(undoxxed.balanceOf(user2) == 10, "fail fiat payement mint");
  }

  function testFiatPaymentMintShouldFailInvalidStatus() public {
    undoxxed.setStatus(Status.allowlist);
    undoxxed.setFiatPayment(user1);
    vm.deal(user1, 100 ether);
    bytes memory signature = sign(user2, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.prank(user1);
    vm.expectRevert(invalidSaleStatus.selector);
    undoxxed.fiatPaymentMint{value : whitelistPrice * 10}(user2, 5, 5, 5, 5, signature);
    vm.prank(owner);
    undoxxed.setStatus(Status.finished);
    vm.prank(user1);
    vm.expectRevert(invalidSaleStatus.selector);
    undoxxed.fiatPaymentMint{value : whitelistPrice * 10}(user2, 5, 5, 5, 5, signature);
  }

  function testFiatPaymentMintShouldFailtInvalidAmountSend() public {
    undoxxed.setStatus(Status.whitelist);
    undoxxed.setFiatPayment(user1);
    vm.deal(user1, 100 ether);
    bytes memory signature = sign(user2, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(invalidAmountSend.selector);
    undoxxed.fiatPaymentMint{value : whitelistPrice * 9}(user2, 5, 5, 5, 5, signature);
  }

  function testFiatPaymentMintShouldFailInvalidSignature() public {
    undoxxed.setStatus(Status.whitelist);
    undoxxed.setFiatPayment(user1);
    vm.deal(user1, 100 ether);
    bytes memory signature = sign(user3, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(invalidSignature.selector);
    undoxxed.fiatPaymentMint{value : whitelistPrice * 10}(user2, 5, 5, 5, 5, signature);
  }

  // test setter

  function testSetStatus() public {
    undoxxed.setStatus(Status.allowlist);
    require(undoxxed.getCurrentStatus() == Status.allowlist, "fail set status");
  }

  function testSetStatusFailOnlyOwner() public {
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert();
    undoxxed.setStatus(Status.allowlist);
  }

  function testSetSigner() public {
    undoxxed.setSigner(user2);
    undoxxed.setStatus(Status.allowlist);
    bytes32 messaggeHash = Verification.getMessageHash(user1, 5, 5, Status.allowlist);
    bytes32 finalHash = Verification.getEthSignedMessageHash(messaggeHash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(user2PrivateKey, finalHash);
    bytes memory signature = abi.encodePacked(r, s, v);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(user1, 5, 5, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 10, "fail mint in allowlist");
  }

  function testSetSignerFailOnlyOwner() public {
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert();
    undoxxed.setSigner(user2);
  }

  function testSetWhitelistPrice() public {
    undoxxed.setWhitelistPrice(0.2 ether);
    undoxxed.setStatus(Status.whitelist);
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.whitelistMint{value: 0.2 ether}(user1, 1, 0, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 1, "fail set whitelist price");
    vm.expectRevert(invalidAmountSend.selector);
    undoxxed.whitelistMint{value: 0.1 ether}(user1, 1, 0, 5, 5, signature);
  }

  function testSetStatusFailNotOwner() public {
    vm.stopPrank();
    vm.prank(user1);
    vm.expectRevert();
    undoxxed.setStatus(Status.allowlist);
  }

  // test view

  function testTokenURIReturnInfo() public {
    string memory expectedURI = "YOUR BASE URI/1.json";
    undoxxed.setStatus(Status.publicMint);
    vm.deal(user1, 10 ether);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.mint{value: 0.15 ether}(user1, 1, 0);
    string memory tokenURI = undoxxed.tokenURI(1);
    require(keccak256(bytes(expectedURI)) == keccak256(bytes(tokenURI)), "fail get correct URI");
  }

  function testTokenURIShouldReturnNothingWhenNotExistingTokenId() public view {
    string memory expectedURI = "";
    string memory tokenURI = undoxxed.tokenURI(1);
    require(keccak256(bytes(expectedURI)) == keccak256(bytes(tokenURI)), "fail get correct URI");
  }

  // test withdraw

  function testWithdraw() public {
    undoxxed.setStatus(Status.publicMint);
    vm.deal(user1, 10 ether);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.mint{value: publicPrice * 20}(user1, 10, 10);
    require(undoxxed.balanceOf(user1) == 20, "fail mint public");
    vm.stopPrank();
    vm.startPrank(owner);
    uint256 balanceOwnerBefore = address(owner).balance;
    undoxxed.withdraw();
    uint256 balanceOwnerAfter = address(owner).balance;
    require(balanceOwnerBefore < balanceOwnerAfter, "fail withdraw");
    require(balanceOwnerAfter == publicPrice * 20, "fail withdraw exact value");
  }

  // test opengem

  function testPermanentProof() public {
    string memory proof = "MY PROOF";
    undoxxed.setStatus(Status.publicMint);
    undoxxed.setTokenProof1(proof);
    vm.deal(user1, 10 ether);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.mint{value: publicPrice * 1}(user1, 1, 0);
    require(undoxxed.balanceOf(user1) == 1, "fail mint public");
    string memory proofGet = undoxxed.tokenProofPermanent(1);
    require(keccak256(bytes(proofGet)) == keccak256(bytes(proof)), "fail get the correct proof");
  }

  function testPermanentProofCover2() public {
    string memory proof = "MY PROOF";
    undoxxed.setStatus(Status.publicMint);
    undoxxed.setTokenProof2(proof);
    vm.deal(user1, 10 ether);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.mint{value: publicPrice * 1}(user1, 0, 1);
    require(undoxxed.balanceOf(user1) == 1, "fail mint public");
    string memory proofGet = undoxxed.tokenProofPermanent(maxSupplyToken1 + 1);
    require(keccak256(bytes(proofGet)) == keccak256(bytes(proof)), "fail get the correct proof");
  }

  function testPermanentURI() public {
    // string memory mediaURI = "YOUR BASE URI/";
    string memory correctMediaURI = "YOUR BASE URI/1.json";
    undoxxed.setStatus(Status.publicMint);
    vm.deal(user1, 10 ether);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.mint{value: publicPrice * 1}(user1, 1, 0);
    require(undoxxed.balanceOf(user1) == 1, "fail mint public");
    string[] memory getMediaURI = undoxxed.tokenURIsPermanent(1);
    require(keccak256(bytes(getMediaURI[0])) == keccak256(bytes(correctMediaURI)), "fail get media URI");
  }
}