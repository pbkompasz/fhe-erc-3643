// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";
import "./interfaces/IERC734.sol";
import "./interfaces/IIdentity.sol";
import "./interfaces/IClaimIssuer.sol";
import "./Storage.sol";

// @notice Identity contract implementing both ERC 734 and ERC 735

contract Identity is Storage, IIdentity, GatewayCaller {
    /**
     * @notice Prevent any direct calls to the implementation contract (marked by _canInteract = false).
     */
    modifier delegatedOnly() {
        require(_canInteract == true, "Interacting with the library contract is forbidden.");
        _;
    }

    modifier onlyManager() {
        // require(
        //     msg.sender == address(this) || keyHasPurpose(keccak256(abi.encode(msg.sender)), 1),
        //     "Permissions: Sender does not have management key"
        // );
        _;
    }

    // TODO Modify implementation to put data into dumb if not claim key
    modifier onlyClaimKey() {
        // require(
        //     msg.sender == address(this) || keyHasPurpose(keccak256(abi.encode(msg.sender)), 3),
        //     "Permissions: Sender does not have claim signer key"
        // );
        _;
    }

    /**
     * @notice constructor of the Identity contract
     * @param initialManagementKey the address of the management key at deployment
     * @param _isLibrary boolean value stating if the contract is library or not
     * calls __Identity_init if contract is not library
     */
    constructor(address initialManagementKey, bool _isLibrary) {
        require(initialManagementKey != address(0), "invalid argument - zero address");

        if (!_isLibrary) {
            __Identity_init(initialManagementKey);
        } else {
            _initialized = true;
        }
    }

    /**
     * @notice When using this contract as an implementation for a proxy, call this initializer with a delegatecall.
     *
     * @param initialManagementKey The ethereum address to be set as the management key of the ONCHAINID.
     */
    function initialize(address initialManagementKey) external {
        require(initialManagementKey != address(0), "invalid argument - zero address");
        __Identity_init(initialManagementKey);
    }

    /**
     * @dev See {IERC734-execute}.
     * @notice Passes an execution instruction to the keymanager.
     * If the sender is an ACTION key and the destination address is not the identity contract itself, then the
     * execution is immediately approved and performed.
     * If the destination address is the identity itself, then the execution would be performed immediately only if
     * the sender is a MANAGEMENT key.
     * Otherwise the execution request must be approved via the `approve` method.
     * @return executionId to use in the approve function, to approve or reject this execution.
     */
    function execute(
        address _to,
        uint256 _value,
        bytes memory _data
    ) external payable override delegatedOnly returns (uint256 executionId) {
        uint256 _executionId = _executionNonce;
        _executions[_executionId].to = _to;
        _executions[_executionId].value = _value;
        _executions[_executionId].data = _data;
        _executionNonce++;

        emit ExecutionRequested(_executionId, _to, _value, _data);

        euint4 ONE = TFHE.asEuint4(1);
        euint4 TWO = TFHE.asEuint4(2);
        ebool isManagement = keyHasPurpose(keccak256(abi.encode(msg.sender)), ONE);
        ebool isActionKeyHolder = TFHE.and(
            TFHE.asEbool(_to != address(this)),
            keyHasPurpose(keccak256(abi.encode(msg.sender)), TWO)
        );
        ebool isExecutable = TFHE.and(isManagement, isActionKeyHolder);

        _decryptExecutionsToApprove(isExecutable, _executionId);
    }

    function _decryptExecutionsToApprove(ebool isExecutable, uint256 _executionId) internal {
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(isExecutable);
        uint256 requestID = Gateway.requestDecryption(
            cts,
            this._executionCallback.selector,
            0,
            block.timestamp + 100,
            false
        );
        addParamsUint256(requestID, _executionId);
    }

    function _executionCallback(uint256 requestID, bool decryptedInput) public onlyGateway returns (uint256) {
        uint256[] memory params = getParamsUint256(requestID);
        bool executable = decryptedInput;
        uint256 _executionId = params[0];
        if (executable) {
            approve(_executionId, true);
        }
        return _executionId;
    }

    /**
     * @dev See {IERC734-getKey}.
     * @notice Implementation of the getKey function from the ERC-734 standard
     * @param _key The public key.  for non-hex and long keys, its the Keccak256 hash of the key
     * @return purposes Returns the full key data, if present in the identity.
     * @return keyType Returns the full key data, if present in the identity.
     * @return key Returns the full key data, if present in the identity.
     */
    function getKey(
        bytes32 _key
    ) external view override returns (euint4[] memory purposes, euint4 keyType, bytes32 key) {
        return (_keys[_key].purposes, _keys[_key].keyType, _keys[_key].key);
    }

    /**
     * @dev See {IERC734-getKeyPurposes}.
     * @notice gets the purposes of a key
     * @param _key The public key.  for non-hex and long keys, its the Keccak256 hash of the key
     * @return _purposes Returns the purposes of the specified key
     */
    function getKeyPurposes(bytes32 _key) external view override returns (euint4[] memory _purposes) {
        return (_keys[_key].purposes);
    }

    /**
     * @dev See {IERC734-getKeysByPurpose}.
     * @notice gets all the keys with a specific purpose from an identity
     * @param _purpose a uint256[] Array of the key types, like 1 = MANAGEMENT, 2 = ACTION, 3 = CLAIM, 4 = ENCRYPTION
     * @return keys Returns an array of public key bytes32 hold by this identity and having the specified purpose
     */
    function getKeysByPurpose(euint4 _purpose) external view override returns (bytes32[] memory keys) {
        return _keysByPurpose[_purpose];
    }

    /**
     * @dev See {IERC735-getClaimIdsByTopic}.
     * @notice Implementation of the getClaimIdsByTopic function from the ERC-735 standard.
     * used to get all the claims from the specified topic
     * @param _topic The identity of the claim i.e. keccak256(abi.encode(_issuer, _topic))
     * @return claimIds Returns an array of claim IDs by topic.
     */
    function getClaimIdsByTopic(euint8 _topic) external view override returns (bytes32[] memory claimIds) {
        return _claimsByTopic[_topic];
    }

    /**
     * @notice implementation of the addKey function of the ERC-734 standard
     * Adds a _key to the identity. The _purpose specifies the purpose of key. Initially we propose four purposes:
     * 1: MANAGEMENT keys, which can manage the identity
     * 2: ACTION keys, which perform actions in this identities name (signing, logins, transactions, etc.)
     * 3: CLAIM signer keys, used to sign claims on other identities which need to be revokable.
     * 4: ENCRYPTION keys, used to encrypt data e.g. hold in claims.
     * MUST only be done by keys of purpose 1, or the identity itself.
     * If its the identity itself, the approval process will determine its approval.
     * @param _key keccak256 representation of an ethereum address
     * @param _type type of key used, which would be a uint256 for different key types. e.g. 1 = ECDSA, 2 = RSA, etc.
     * @param _purpose a uint256 specifying the key type, like 1 = MANAGEMENT, 2 = ACTION, 3 = CLAIM, 4 = ENCRYPTION
     * @return success Returns TRUE if the addition was successful and FALSE if not
     */
    function addKey(bytes32 _key, euint4 _purpose, euint4 _type) public override delegatedOnly returns (bool success) {
        // ) public override delegatedOnly onlyManager returns (bool success) {
        // TODO Add not manager dumb key
        if (_keys[_key].key == _key) {
            euint4[] memory _purposes = _keys[_key].purposes;
            for (uint keyPurposeIndex = 0; keyPurposeIndex < _purposes.length; keyPurposeIndex++) {
                euint4 purpose = _purposes[keyPurposeIndex];

                // TODO
                // if (purpose == _purpose) {
                //     revert("Conflict: Key already has purpose");
                // }
            }

            _keys[_key].purposes.push(_purpose);
        } else {
            _keys[_key].key = _key;
            _keys[_key].purposes = [_purpose];
            _keys[_key].keyType = _type;
        }

        _keysByPurpose[_purpose].push(_key);

        emit KeyAdded(_key, _purpose, _type);

        return true;
    }

    /**
     *  @dev See {IERC734-approve}.
     *  @notice Approves an execution.
     *  If the sender is an ACTION key and the destination address is not the identity contract itself, then the
     *  approval is authorized and the operation would be performed.
     *  If the destination address is the identity itself, then the execution would be authorized and performed only
     *  if the sender is a MANAGEMENT key.
     */
    function approve(uint256 _id, bool _approve) public override delegatedOnly returns (bool success) {
        require(_id < _executionNonce, "Cannot approve a non-existing execution");
        require(!_executions[_id].executed, "Request already executed");

        // TODO Same
        // if (_executions[_id].to == address(this)) {
        //     require(keyHasPurpose(keccak256(abi.encode(msg.sender)), 1), "Sender does not have management key");
        // } else {
        //     require(keyHasPurpose(keccak256(abi.encode(msg.sender)), 2), "Sender does not have action key");
        // }

        emit Approved(_id, _approve);

        if (_approve == true) {
            _executions[_id].approved = true;

            // solhint-disable-next-line avoid-low-level-calls
            (success, ) = _executions[_id].to.call{ value: (_executions[_id].value) }(_executions[_id].data);

            if (success) {
                _executions[_id].executed = true;

                emit Executed(_id, _executions[_id].to, _executions[_id].value, _executions[_id].data);

                return true;
            } else {
                emit ExecutionFailed(_id, _executions[_id].to, _executions[_id].value, _executions[_id].data);

                return false;
            }
        } else {
            _executions[_id].approved = false;
        }
        return false;
    }

    // function removeKey(bytes32 _key, euint4 _purpose) public override delegatedOnly onlyManager returns (bool success) {
    function removeKey(bytes32 _key, euint4 _purpose) public override delegatedOnly returns (bool success) {
        require(_keys[_key].key == _key, "NonExisting: Key isn't registered");
        euint4[] memory _purposes = _keys[_key].purposes;
        euint4 INVALID_POS = TFHE.asEuint4(_purposes.length - 1);

        uint purposeIndex = 0;
        while (purposeIndex != _purposes.length - 2) {
            purposeIndex++;
            ebool areDifferent = TFHE.ne(_purposes[purposeIndex], _purpose);
            TFHE.select(areDifferent, TFHE.asEuint4(purposeIndex), INVALID_POS);
        }
        if (purposeIndex == _purposes.length + 1) {
            revert("NonExisting: Key doesn't have such purpose");
        }

        _purposes[purposeIndex] = _purposes[_purposes.length - 1];
        _keys[_key].purposes = _purposes;
        _keys[_key].purposes.pop();

        uint keyIndex = 0;
        uint arrayLength = _keysByPurpose[_purpose].length;

        while (_keysByPurpose[_purpose][keyIndex] != _key) {
            keyIndex++;

            if (keyIndex >= arrayLength) {
                break;
            }
        }

        _keysByPurpose[_purpose][keyIndex] = _keysByPurpose[_purpose][arrayLength - 1];
        _keysByPurpose[_purpose].pop();

        euint4 keyType = _keys[_key].keyType;

        if (_purposes.length - 1 == 0) {
            delete _keys[_key];
        }

        emit KeyRemoved(_key, _purpose, keyType);

        return true;
    }

    function addClaim(
        euint8 _topic,
        euint8 _scheme,
        address _issuer,
        address _data
    )
        public
        override
        // ) public override delegatedOnly onlyClaimKey returns (bytes32 claimRequestId) {
        delegatedOnly
        returns (bytes32 claimRequestId)
    {
        // TODO
        // if (_issuer != address(this)) {
        //     require(IClaimIssuer(_issuer).isClaimValid(IIdentity(address(this)), _topic, _data), "invalid claim");
        // }

        bytes32 claimId = keccak256(abi.encode(_issuer, _topic));
        _claims[claimId].topic = _topic;
        _claims[claimId].schemeId = _scheme;
        _claims[claimId].dataContainer = _data;

        // TODO If claimId is different put to error pos
        if (_claims[claimId].issuer != _issuer) {
            _claimsByTopic[_topic].push(claimId);
            _claims[claimId].issuer = _issuer;

            emit ClaimAdded(claimId, _topic, _scheme, _issuer, _data);
        } else {
            emit ClaimChanged(claimId, _topic, _scheme, _issuer, _data);
        }
        return claimId;
    }

    /**
     * @dev See {IERC735-removeClaim}.
     * @notice Implementation of the removeClaim function from the ERC-735 standard
     * Require that the msg.sender has management key.
     * Can only be removed by the claim issuer, or the claim holder itself.
     *
     * @param _claimId The identity of the claim i.e. keccak256(abi.encode(_issuer, _topic))
     *
     * @return success Returns TRUE when the claim was removed.
     * triggers ClaimRemoved event
     */
    // function removeClaim(bytes32 _claimId) public override delegatedOnly onlyClaimKey returns (bool success) {
    function removeClaim(bytes32 _claimId) public override delegatedOnly returns (bool success) {
        euint8 _topic = _claims[_claimId].topic;
        // TODO
        // if (_topic == 0) {
        //     revert("NonExisting: There is no claim with this ID");
        // }

        uint claimIndex = 0;
        uint arrayLength = _claimsByTopic[_topic].length;
        while (_claimsByTopic[_topic][claimIndex] != _claimId) {
            claimIndex++;

            if (claimIndex >= arrayLength) {
                break;
            }
        }

        _claimsByTopic[_topic][claimIndex] = _claimsByTopic[_topic][arrayLength - 1];
        _claimsByTopic[_topic].pop();

        emit ClaimRemoved(
            _claimId,
            _claims[_claimId].topic,
            _claims[_claimId].schemeId,
            _claims[_claimId].issuer,
            _claims[_claimId].dataContainer
        );

        delete _claims[_claimId];

        return true;
    }

    function getClaim(
        bytes32 _claimId
    ) public view override returns (euint8 topic, euint8 scheme, address issuer, address dataContainer) {
        return (
            _claims[_claimId].topic,
            _claims[_claimId].schemeId,
            _claims[_claimId].issuer,
            _claims[_claimId].dataContainer
        );
    }

    /**
     * @dev See {IERC734-keyHasPurpose}.
     * @notice Returns true if the key has MANAGEMENT purpose or the specified purpose or lower (this requires only 1 decryption in the approve).
     */
    function keyHasPurpose(bytes32 _key, euint4 _purpose) public override returns (ebool result) {
        Key memory key = _keys[_key];
        if (key.key == 0) return TFHE.asEbool(false);

        euint4 okayCandidate = TFHE.asEuint4(0);
        euint4 ONE = TFHE.asEuint4(1);
        euint4 ZERO = TFHE.asEuint4(0);
        for (uint keyPurposeIndex = 0; keyPurposeIndex < key.purposes.length; keyPurposeIndex++) {
            euint4 purpose = key.purposes[keyPurposeIndex];

            ebool isOkay = TFHE.or(TFHE.eq(purpose, ONE), TFHE.ge(purpose, _purpose));
            TFHE.add(okayCandidate, TFHE.select(isOkay, TFHE.asEuint4(1), TFHE.asEuint4(0)));
        }

        return TFHE.gt(okayCandidate, ZERO);
    }

    /**
     * @dev Checks if a claim is valid. Claims issued by the identity are self-attested claims. They do not have a
     * built-in revocation mechanism and are considered valid as long as their signature is valid and they are still
     * stored by the identity contract.
     * @param _identity the identity contract related to the claim
     * @param claimTopic the claim topic of the claim
     * @param sig the signature of the claim
     * @param data the data field of the claim
     * @return claimValid true if the claim is valid, false otherwise
     */
    function isClaimValid(
        IIdentity _identity,
        uint256 claimTopic,
        bytes memory sig,
        bytes memory data
    ) public virtual override returns (ebool claimValid) {
        bytes32 dataHash = keccak256(abi.encode(_identity, claimTopic, data));
        // Use abi.encodePacked to concatenate the message prefix and the message to sign.
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));

        // Recover address of data signer
        address recovered = getRecoveredAddress(sig, prefixedHash);

        // Take hash of recovered address
        bytes32 hashedAddr = keccak256(abi.encode(recovered));

        euint4 THREE = TFHE.asEuint4(3);
        // Does the trusted identifier have they key which signed the user's claim?
        //  && (isClaimRevoked(_claimId) == false)
        return (keyHasPurpose(hashedAddr, THREE));
    }

    /**
     * @dev returns the address that signed the given data
     * @param sig the signature of the data
     * @param dataHash the data that was signed
     * returns the address that signed dataHash and created the signature sig
     */
    function getRecoveredAddress(bytes memory sig, bytes32 dataHash) public pure returns (address addr) {
        bytes32 ra;
        bytes32 sa;
        uint8 va;

        // Check the signature length
        if (sig.length != 65) {
            return address(0);
        }

        // Divide the signature in r, s and v variables
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ra := mload(add(sig, 32))
            sa := mload(add(sig, 64))
            va := byte(0, mload(add(sig, 96)))
        }

        if (va < 27) {
            va += 27;
        }

        address recoveredAddress = ecrecover(dataHash, va, ra, sa);

        return (recoveredAddress);
    }

    /**
     * @notice Initializer internal function for the Identity contract.
     *
     * @param initialManagementKey The ethereum address to be set as the management key of the ONCHAINID.
     */
    // solhint-disable-next-line func-name-mixedcase
    function __Identity_init(address initialManagementKey) internal {
        require(!_initialized || _isConstructor(), "Initial key was already setup.");
        _initialized = true;
        _canInteract = true;

        euint4 ONE = TFHE.asEuint4(1);

        bytes32 _key = keccak256(abi.encode(initialManagementKey));
        _keys[_key].key = _key;
        _keys[_key].purposes = [ONE];
        _keys[_key].keyType = ONE;
        _keysByPurpose[ONE].push(_key);
        emit KeyAdded(_key, ONE, ONE);
    }

    /**
     * @notice Computes if the context in which the function is called is a constructor or not.
     *
     * @return true if the context is a constructor.
     */
    function _isConstructor() private view returns (bool) {
        address self = address(this);
        uint256 cs;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            cs := extcodesize(self)
        }
        return cs == 0;
    }
}
