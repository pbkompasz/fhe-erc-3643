// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

contract DVD is GatewayCaller {
    constructor() {}

    event RequestSubmitted();

    struct Requested {
        address requestedBy;
        euint4 tokenWant;
        euint32 allowance;
        // 0 - Created
        // 1 - in-progress
        // 2 - completed
        euint4 status;
        // This is safe because it points to a request in another mapping
        // And an event is emitted anyways when a transaction happens
        uint16 matchingRequest;
    }
    mapping(euint4 => Requested[]) public requests;

    bool isBusy = false;
    uint16 decryptResult;

    struct DecryptRequest {
        euint4 tokenA;
        euint4 tokenB;
    }

    struct Transfer {
        eaddress userA;
        eaddress userB;
        euint4 tokenA;
        euint4 tokenB;
        euint32 amount;
    }

    Transfer[] public transfers;

    // TODO Redo to make it more efficient:
    // https://ethereum.stackexchange.com/questions/129668/how-to-efficiently-implement-a-fifo-array-queue-in-solidity
    uint256 pos = 0;
    DecryptRequest[] decryptionQue;

    function submitRequest(
        einput encryptedTokenHas,
        einput encryptedTokenWant,
        einput encryptedAllowance,
        bytes calldata inputProof
    ) external {
        euint4 tokenA = TFHE.asEuint4(encryptedTokenHas, inputProof);
        euint4 tokenB = TFHE.asEuint4(encryptedTokenWant, inputProof);
        euint32 allowance = TFHE.asEuint32(encryptedAllowance, inputProof);
        Requested memory newRequested = Requested(msg.sender, tokenB, allowance, TFHE.asEuint4(0), 404);
        requests[tokenA].push(newRequested);
        euint16 firstMatching = _hasMatchingRequest(newRequested);
        decryptionQue.push(DecryptRequest(tokenA, tokenB));
        _submitDecrypt(firstMatching);
        emit RequestSubmitted();
    }

    function _initiateTransfer(
        euint4 _requestA,
        uint256 posA,
        euint4 _requestB,
        uint256 posB
    ) internal returns (uint256) {
        requests[_requestA][posA].status = TFHE.asEuint4(1);
        requests[_requestB][posB].status = TFHE.asEuint4(1);

        return transfers.length;
    }

    function takeTransfer(euint8 transferId) internal {}

    // Returns the position of the first matching request or 404
    function _hasMatchingRequest(Requested memory requested) internal returns (euint16) {
        uint16 length = uint16(requests[requested.tokenWant].length);
        euint32 minAllownace = requested.allowance;
        Requested[] memory toCheckAgainst = requests[requested.tokenWant];
        euint16 isOkay = TFHE.asEuint16(404);
        for (uint16 i = 0; i < length; i++) {
            ebool isMatching = TFHE.eq(requested.tokenWant, toCheckAgainst[i].tokenWant);
            ebool isSufficient = TFHE.eq(minAllownace, toCheckAgainst[i].allowance);
            isOkay = TFHE.add(
                isOkay,
                TFHE.select(TFHE.and(isMatching, isSufficient), TFHE.asEuint16(i), TFHE.asEuint16(404))
            );
        }

        return isOkay;
    }

    function _submitDecrypt(euint16 posToDecrypt) internal {
        isBusy = true;
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(posToDecrypt);
        uint256 requestID = Gateway.requestDecryption(
            cts,
            this._decryptCallback.selector,
            0,
            block.timestamp + 100,
            false
        );
        addParamsUint256(requestID, decryptionQue.length - 1);
    }

    function _decryptCallback(uint16 requestID, uint16 decryptedInput) public onlyGateway returns (bool) {
        uint16 firstMatching = decryptedInput;
        decryptResult = firstMatching;
        uint256[] memory params = getParamsUint256(requestID);
        uint256 quePos = params[0];
        if (firstMatching != 404) {
            DecryptRequest memory dr = decryptionQue[quePos];
            _initiateTransfer(dr.tokenA, requests[dr.tokenA].length - 1, dr.tokenB, firstMatching);
        }
        isBusy = false;
        return isBusy;
    }

    function isDecryptionQueFree() external view returns (bool) {
        return !isBusy;
    }

    function getDecryptQueSize() external view returns (uint256) {
        return decryptionQue.length;
    }

    function getDecryptResult() external view returns (uint256) {
        return decryptResult;
    }
}
