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

  // test deploy

  function testDeployContract() public {
    new UNDOXXED();
  }

  // test allowlist

  function testAllowlistMint() public {
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(5, 5, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 10, "fail mint in allowlist");
  }

  function testAllowlistMint1Copies() public {
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(1, 0, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 1, "fail mint in allowlist");
  }

  function testAllowlistMint20Copies() public {
    bytes memory signature = sign(user1, 10, 10, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(10, 10, 10, 10, signature);
    require(undoxxed.balanceOf(user1) == 20, "fail mint in allowlist");
  }

  function testAllowlistMintFuzzAmountMint(uint256 _amount1, uint256 _amount2) public {
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    if (_amount1 < 6 && _amount2 < 6) {
      undoxxed.allowlistMint(_amount1, _amount2, 5, 5, signature);
      require(undoxxed.balanceOf(user1) == _amount1 + _amount2, "fail mint in allowlist");
    } else {
      if (_amount1 > 5 ) {
        vm.expectRevert(exceedAllowedToken1Mint.selector);
      } else if (_amount2 > 5 ) {
        vm.expectRevert(exceedAllowedToken2Mint.selector);
      }
      undoxxed.allowlistMint(_amount1, _amount2, 5, 5, signature);
    }
  }

  function testAllowlistMintLowerThanAllowed() public {
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(2, 2, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 4, "fail mint in allowlist");
  }

  function testAllowlistMintAllSupply() public {
    bytes memory signature = sign(user1, 250, 250, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(maxSupplyToken1, maxSupplyToken2, 250, 250, signature);
    require(undoxxed.balanceOf(user1) == maxSupply, "fail mint all supply in allowlist");
  }

  function testAllowlistMintAllSupplyMultipleCall() public {
    bytes memory signature = sign(user1, 250, 250, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(maxSupplyToken1 - 1, maxSupplyToken2 - 1, 250, 250, signature);
    require(undoxxed.balanceOf(user1) == maxSupply - 2, "fail mint all supply in allowlist");
    undoxxed.allowlistMint(1, 1, 250, 250, signature);
    require(undoxxed.balanceOf(user1) == maxSupply, "fail mint all supply in allowlist");
  }

  function testAllowlistMintGreaterThanAllowedShouldFail() public {
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(exceedAllowedToken1Mint.selector);
    undoxxed.allowlistMint(6, 6, 5, 5, signature);
  }

  function testAllowlistMintGreaterThanAllowedShouldFailMultipleCall() public {
    bytes memory signature = sign(user1, 5, 5, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(2, 2, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 4, "fail mint in allowlist");
    vm.expectRevert(exceedAllowedToken1Mint.selector);
    undoxxed.allowlistMint(4, 3, 5, 5, signature);
  }

  function testAllowlistMintMoreThanAllSupplyShouldFail() public {
    bytes memory signature = sign(user1, 250, 250, Status.allowlist);
    bytes memory signature2 = sign(user2, 250, 250, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(maxSupplyToken1, maxSupplyToken2, 250, 250, signature);
    require(undoxxed.balanceOf(user1) == maxSupply, "fail mint all supply in allowlist");
    vm.stopPrank();
    vm.startPrank(user2);
    vm.expectRevert(maxSupplyToken1Reach.selector);
    undoxxed.allowlistMint(1, 1, 250, 250, signature2);
  }

  function testAllowlistMintShouldReturnCorrectURI() public {
    string memory cover1URI = "Black";
    string memory cover2URI = "Purple";
    undoxxed.setCover1BaseURI(cover1URI);
    undoxxed.setCover2BaseURI(cover2URI);
    bytes memory signature = sign(user1, 1, 1, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(1, 1, 1, 1, signature);
    require(undoxxed.balanceOf(user1) == 2, "fail mint in allowlist");
    string memory uri = undoxxed.tokenURI(1);
    require(keccak256(bytes(cover1URI)) == keccak256(bytes(uri)), "fail get cover 1 uri");
    uri = undoxxed.tokenURI(2);
    require(keccak256(bytes(cover2URI)) == keccak256(bytes(uri)), "fail get cover 2 uri");
  }

  // test whitelist

  function testWhitelistMint1Copies() public {
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.whitelistMint{value: whitelistPrice * 1}(1, 0, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 1, "fail mint in whitelist");
  }

  function testWhitelistMintShouldSuccess() public {
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.whitelistMint{value: 1 ether}(5, 5, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 10, "fail mint in whitelist");
  }

  function testWhitelistMintShouldSuccessPublicPhase() public {
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.whitelistMint{value: 1 ether}(5, 5, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 10, "fail mint in whitelist");
  }

  function testWhitelistMintFuzz(uint256 _amount1, uint256 _amount2) public {
    vm.deal(user1, uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    uint256 amountToSend;
    unchecked {
      amountToSend = 0.1 ether * (_amount1 + _amount2);
    }
    if (_amount1 < 6 && _amount2 < 6) {
      undoxxed.whitelistMint{value: amountToSend}(_amount1, _amount2, 5, 5, signature);
      require(undoxxed.balanceOf(user1) == _amount1 + _amount2, "fail mint in whitelist");
    } else {
      if (_amount1 > 5) {
        vm.expectRevert();
      } else if (_amount2 > 5) {
        vm.expectRevert();
      }
      undoxxed.whitelistMint{value: amountToSend}(_amount1, _amount2, 5, 5, signature);
    }
  }

  function testWhitelistMintShouldSuccessMultipleCall() public {
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.whitelistMint{value: 0.2 ether}(2, 0, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 2, "fail mint in whitelist");
    undoxxed.whitelistMint{value: 0.8 ether}(3, 5, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 10, "fail mint in whitelist in second call");
  }

  function testWhitelistMintShouldFailInvalidUser() public {
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user2);
    vm.deal(user2, 100 ether);
    vm.expectRevert(invalidSignature.selector);
    undoxxed.whitelistMint{value: 1 ether}(5, 5, 5, 5, signature);
  }

  function testWhitelistMintShouldFailInvalidAmountSend() public {
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    vm.expectRevert(invalidAmountSend.selector);
    undoxxed.whitelistMint{value: whitelistPrice * 9}(5, 5, 5, 5, signature);
  }

  // test private whitelist

  function testPrivateWhitelistShouldsuccess() public {
    bytes memory signature = sign(user1, 1, 0, Status.privateWhitelist);
    undoxxed.setReserveToken1(10);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.privateWhitelistMint{value: whitelistPrice * 1}(1, 0, 1, 0, signature);
  }

  function testPrivatewhitelistShouldSuccessWhenAllSupplyAlreadyMinted() public {
    uint256 privateWhitelistSupply = 10;
    /** @dev Mint all supply */
    undoxxed.setReserveToken1(privateWhitelistSupply);
    undoxxed.setReserveToken2(privateWhitelistSupply);
    bytes memory signature = sign(user1, 250, 250, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(maxSupplyToken1 - privateWhitelistSupply, maxSupplyToken2 - privateWhitelistSupply, 250, 250, signature);
    require(undoxxed.balanceOf(user1) == maxSupply - (privateWhitelistSupply * 2), "fail mint all supply in allowlist");
    vm.expectRevert(maxSupplyToken1Reach.selector);
    undoxxed.allowlistMint(1, 0, 250, 250, signature);
    vm.expectRevert(maxSupplyToken2Reach.selector);
    undoxxed.allowlistMint(0, 1, 250, 250, signature);
    vm.stopPrank();
    vm.startPrank(owner);
    bytes memory signature2 = sign(user2, 1, 0, Status.privateWhitelist);
    vm.stopPrank();
    vm.startPrank(user2);
    vm.deal(user2, 100 ether);
    undoxxed.privateWhitelistMint{value: whitelistPrice * 1}(1, 0, 1, 0, signature2);
  }

  function testPrivateWhitelistShouldSuccessAndAfterNormalWhitelistShouldSuccess() public {
    uint256 privateWhitelistSupply = 10;
    /** @dev Mint all supply */
    undoxxed.setReserveToken1(privateWhitelistSupply);
    undoxxed.setReserveToken2(privateWhitelistSupply);
    bytes memory signature = sign(user1, 250, 250, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(maxSupplyToken1 - privateWhitelistSupply - 1, maxSupplyToken2 - privateWhitelistSupply - 1, 250, 250, signature);
    require(undoxxed.balanceOf(user1) == maxSupply - (privateWhitelistSupply * 2) - 2, "fail mint all supply - 1 in allowlist");
    vm.stopPrank();
    vm.startPrank(owner);
    bytes memory signature2 = sign(user2, 10, 10, Status.privateWhitelist);
    vm.stopPrank();
    vm.startPrank(user2);
    vm.deal(user2, 100 ether);
    undoxxed.privateWhitelistMint{value: whitelistPrice * 20}(10, 10, 10, 10, signature2);
    bytes memory signature3 = sign(user3, 10, 10, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user3);
    vm.deal(user3, 100 ether);
    undoxxed.whitelistMint{value: whitelistPrice}(1, 0, 10, 10, signature3);
  }

  function testPrivateWhitelistShouldFailWhenNoSupplyAttributed() public {
    bytes memory signature = sign(user1, 10, 0, Status.privateWhitelist);
    undoxxed.setReserveToken1(10);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.privateWhitelistMint{value: whitelistPrice * 10}(10, 0, 10, 0, signature);
    bytes memory signature2 = sign(user2, 10, 0, Status.privateWhitelist);
    vm.stopPrank();
    vm.startPrank(user2);
    vm.deal(user2, 100 ether);
    vm.expectRevert(privateWhitelistToken1SoldOut.selector);
    undoxxed.privateWhitelistMint{value: whitelistPrice * 1}(1, 0, 10, 0, signature2);
  }

  // test mint

  function testPublicMintShouldSuccess() public {
    undoxxed.setPublic();
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.mint{value: publicPrice * 20}(10, 10);
    require(undoxxed.balanceOf(user1) == 20, "fail mint in public");
  }

  function testPublicMIntShouldSuccessMultipleCall() public {
    undoxxed.setPublic();
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.mint{value: publicPrice * 10}(5, 5);
    require(undoxxed.balanceOf(user1) == 10, "fail mint in public");
    undoxxed.mint{value: publicPrice * 10}(5, 5);
    require(undoxxed.balanceOf(user1) == 20, "fail mint in public");
  }

  function testPublicMintShouldRevertInvalidAmountSend() public {
    undoxxed.setPublic();
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    vm.expectRevert(invalidAmountSend.selector);
    undoxxed.mint{value: publicPrice * 19}(10, 10);
  }

  // test setter

  function testSetPublic() public {
    undoxxed.setPublic();
    bool isPublic = undoxxed.isPublic();
    require(isPublic == true, "fail set public");
  }

  function testSetStatusFailOnlyOwner() public {
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert();
    undoxxed.setPublic();
  }

  function testSetSigner() public {
    undoxxed.setSigner(user2);
    bytes32 messaggeHash = Verification.getMessageHash(user1, 5, 5, Status.allowlist);
    bytes32 finalHash = Verification.getEthSignedMessageHash(messaggeHash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(user2PrivateKey, finalHash);
    bytes memory signature = abi.encodePacked(r, s, v);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(5, 5, 5, 5, signature);
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
    bytes memory signature = sign(user1, 5, 5, Status.whitelist);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    undoxxed.whitelistMint{value: 0.2 ether}(1, 0, 5, 5, signature);
    require(undoxxed.balanceOf(user1) == 1, "fail set whitelist price");
    vm.expectRevert(invalidAmountSend.selector);
    undoxxed.whitelistMint{value: 0.1 ether}(1, 0, 5, 5, signature);
  }

  function testSetPrivatewhitelistToken1ShouldSuccess() public {
    uint256 quantityPrivatewhitelist = 10;
    undoxxed.setReserveToken1(quantityPrivatewhitelist);
    vm.expectRevert();
    undoxxed.setReserveToken1(1);
    bytes memory signature = sign(user1, 250, 250, Status.allowlist);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.allowlistMint(maxSupplyToken1 - quantityPrivatewhitelist - 1, maxSupplyToken2 - quantityPrivatewhitelist, 250, 250, signature);
    vm.stopPrank();
    vm.startPrank(owner);
    undoxxed.setReserveToken1(11);
    vm.expectRevert(noSupplyAvailableToken1.selector);
    undoxxed.setReserveToken1(12);
  }

  // test view

  function testTokenURIReturnInfo() public {
    string memory expectedURI = "ipfs://QmRKmHJfScUq7ZE8DcXjoUMvHHhQvXso7yzfGTbWEck6PA";
    undoxxed.setPublic();
    vm.deal(user1, 10 ether);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.mint{value: 0.15 ether}(1, 0);
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
    uint256 basicPercent = 6000;
    undoxxed.setPublic();
    vm.deal(user1, 10 ether);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.mint{value: publicPrice * 20}(10, 10);
    require(undoxxed.balanceOf(user1) == 20, "fail mint public");
    vm.stopPrank();
    vm.startPrank(owner);
    uint256 balanceOwnerBefore = address(owner).balance;
    undoxxed.withdraw();
    uint256 balanceOwnerAfter = address(owner).balance;
    require(balanceOwnerBefore < balanceOwnerAfter, "fail withdraw");
    require(balanceOwnerAfter == publicPrice * 20 * basicPercent / 10000, "fail withdraw exact value");
  }

  function testWithdrawShouldFailCallerNotOwner() public {
    undoxxed.setPublic();
    vm.deal(user1, 10 ether);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.mint{value: publicPrice * 20}(10, 10);
    require(undoxxed.balanceOf(user1) == 20, "fail mint public");
    vm.stopPrank();
    vm.startPrank(user2);
    vm.expectRevert("Ownable: caller is not the owner");
    undoxxed.withdraw();
  }

  // test opengem

  function testPermanentProof() public {
    string memory proof = "MY PROOF";
    undoxxed.setPublic();
    undoxxed.setTokenProof1(proof);
    vm.deal(user1, 10 ether);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.mint{value: publicPrice * 1}(1, 0);
    require(undoxxed.balanceOf(user1) == 1, "fail mint public");
    string memory proofGet = undoxxed.tokenProofPermanent(1);
    require(keccak256(bytes(proofGet)) == keccak256(bytes(proof)), "fail get the correct proof");
  }

  function testPermanentProofCover2() public {
    string memory proof = "MY PROOF";
    undoxxed.setPublic();
    undoxxed.setTokenProof2(proof);
    vm.deal(user1, 10 ether);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.mint{value: publicPrice * 1}(0, 1);
    require(undoxxed.balanceOf(user1) == 1, "fail mint public");
    string memory proofGet = undoxxed.tokenProofPermanent(1);
    require(keccak256(bytes(proofGet)) == keccak256(bytes(proof)), "fail get the correct proof");
  }

  function testPermanentURI() public {
    string memory correctURI = "YOUR BASE URI/1.json";
    undoxxed.setPublic();
    undoxxed.setCover1BaseURI(correctURI);
    vm.deal(user1, 10 ether);
    vm.stopPrank();
    vm.startPrank(user1);
    undoxxed.mint{value: publicPrice * 1}(1, 0);
    require(undoxxed.balanceOf(user1) == 1, "fail mint public");
    string[] memory getMediaURI = undoxxed.tokenURIsPermanent(1);
    require(keccak256(bytes(getMediaURI[getMediaURI.length - 1])) == keccak256(bytes(correctURI)), "fail get media URI");
  }
}