// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Status } from "../IUNDOXXED.sol";

library Verification {
  function getMessageHash(address _to, uint256 _amount, Status _status) public pure returns (bytes32) {
    return keccak256(
      abi.encodePacked(
        _to,
        _amount,
        _status
      )
    );
  }

  function verifySignature(
    address _signer,
    address _to,
    uint256 _amount,
    Status _status,
    bytes memory _signature
  )
    internal
    pure
    returns (bool)
  {
    bytes32 messageHash = getMessageHash(_to, _amount, _status);
    bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

    return recoverSigner(ethSignedMessageHash, _signature) == _signer;
  }

  function getEthSignedMessageHash(
    bytes32 _messageHash
  ) public pure returns (bytes32) {
    /*
    Signature is produced by signing a keccak256 hash with the following format:
    "\x19Ethereum Signed Message\n" + len(msg) + msg
    */
    return keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
    );
  }

  function recoverSigner(
    bytes32 _ethSignedMessageHash,
    bytes memory _signature
  ) public pure returns (address) {
    (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
    return ecrecover(_ethSignedMessageHash, v, r, s);
  }

  function splitSignature(
    bytes memory _sig
  ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
    require(_sig.length == 65, "invalid signature length");
    assembly {
      // first 32 bytes, after the length prefix
      r := mload(add(_sig, 32))
      // second 32 bytes
      s := mload(add(_sig, 64))
      // final byte (first byte of the next 32 bytes)
      v := byte(0, mload(add(_sig, 96)))
    }
  }
}