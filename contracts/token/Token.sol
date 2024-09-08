// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "fhevm/lib/TFHE.sol";
import "./IToken.sol";
import "./TokenStorage.sol";
import "./ConfidentialTokenStorage.sol";
import "../compliance/ICompliance.sol";
import "../roles/AgentRole.sol";

// TODO
// Write identity and claim manager test
// Write confidential and non-confidential registries
// Finish up with token
// Compliance test
// Compliance module
// Cleanup README mentioned the two registries
// look into allow

// 0 - Plaintext everything
// 1 - Confidential investors
// 2 - Confidential compliance
// 3 - Confidential everything

// How it works
// Create identity for investorA, investorB and claim issuer
// Do KYC and claim issuer issues claims for invA and invB
// Investors authorizes identity ???
// Setup compliance module for asset
// Do a test transfer

abstract contract SecurityToken is IToken, Ownable, TokenStorage, ConfidentialTokenStorage, AgentRole {
    bool isConfidential;
    mapping(euint4 => bytes4) private selectors;
    ICompliance internal _tokenCompliance;
    ICompliance internal _tokenComplianceConfidential;
    event TransferEncrypted(eaddress indexed from, eaddress indexed to);

    constructor(bool _isConfidential, address _identityRegistry, address _onchainID) {
        isConfidential = _isConfidential;
        setIdentityRegistry(_identityRegistry);
        _tokenOnchainID = _onchainID;
    }

    modifier whenNotPaused() {
        // require(!_tokenPaused, "Pausable: paused");
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is paused.
    modifier whenPaused() {
        // require(_tokenPaused, "Pausable: not paused");
        _;
    }

    function init(address _compliance, string memory _name, string memory _symbol, uint8 _decimals) external {
        require(owner() == address(0), "already initialized");
        require(
            keccak256(abi.encode(_name)) != keccak256(abi.encode("")) &&
                keccak256(abi.encode(_symbol)) != keccak256(abi.encode("")),
            "invalid argument - empty string"
        );
        require(0 <= _decimals && _decimals <= 18, "decimals between 0 and 18");
        _tokenName = _name;
        _tokenSymbol = _symbol;
        _tokenDecimals = _decimals;
        _tokenPaused = true;
        setCompliance(_compliance);
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    function initConfidential(
        eaddress _compliance,
        einput _name,
        einput _symbol,
        einput _decimals,
        bytes calldata inputProof
    ) external {
        // require(owner() == address(0), "already initialized");
        // require(_identityRegistry != address(0) && _compliance != address(0), "invalid argument - zero address");
        // require(0 <= _decimals && _decimals <= 18, "decimals between 0 and 18");
        _tokenNameEncrypted = TFHE.asEbytes256(_name, inputProof);
        _tokenSymbolEncrypted = TFHE.asEbytes256(_symbol, inputProof);
        _tokenDecimalsEncrypted = TFHE.asEuint8(_decimals, inputProof);
        _tokenPausedEncrypted = TFHE.asEbool(true);
        // setComplianceConfidential(_compliance);
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    function approve(address _spender, uint256 _amount) external virtual override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function increaseAllowance(address _spender, uint256 _addedValue) external virtual returns (bool) {
        _approve(msg.sender, _spender, _allowances[msg.sender][_spender] + (_addedValue));
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _subtractedValue) external virtual returns (bool) {
        _approve(msg.sender, _spender, _allowances[msg.sender][_spender] - _subtractedValue);
        return true;
    }

    function setName(string calldata _name) external override onlyOwner {
        require(keccak256(abi.encode(_name)) != keccak256(abi.encode("")), "invalid argument - empty string");
        _tokenName = _name;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    function setSymbol(string calldata _symbol) external override onlyOwner {
        require(keccak256(abi.encode(_symbol)) != keccak256(abi.encode("")), "invalid argument - empty string");
        _tokenSymbol = _symbol;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    function setOnchainID(address _onchainID) external override onlyOwner {
        _tokenOnchainID = _onchainID;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    function pause() external override onlyAgent whenNotPaused {
        _tokenPaused = true;
        emit Paused(msg.sender);
    }

    function unpause() external override onlyAgent whenPaused {
        _tokenPaused = false;
        emit Unpaused(msg.sender);
    }

    function recoveryAddress(
        address /*_lostWallet*/,
        address /*_newWallet*/,
        address /*_investorOnchainID*/
    ) external override onlyAgent returns (bool) {
        revert("Not implemented");
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function allowance(address _owner, address _spender) external view virtual override returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function identityRegistry() external view override returns (IIdentityRegistry) {
        return _tokenIdentityRegistry;
    }

    function compliance() external view override returns (ICompliance) {
        return _tokenCompliance;
    }

    function paused() external view override returns (bool) {
        return _tokenPaused;
    }

    function isFrozen(address _userAddress) external view override returns (bool) {
        return _frozen[_userAddress];
    }

    function getFrozenTokens(address _userAddress) external view override returns (uint256) {
        return _frozenTokens[_userAddress];
    }

    function decimals() external view override returns (uint8) {
        return _tokenDecimals;
    }

    function name() external view override returns (string memory) {
        return _tokenName;
    }

    function onchainID() external view override returns (address) {
        return _tokenOnchainID;
    }

    function symbol() external view override returns (string memory) {
        return _tokenSymbol;
    }

    function version() external pure override returns (string memory) {
        return _TOKEN_VERSION;
    }

    string private revertMessage;
    function _revertTransferEncrypted() internal {
        revert(revertMessage);
    }

    eaddress to;
    eaddress from;
    euint32 amount;
    function _transferEncrypted() internal returns (bool) {
        eaddress _from = from;
        eaddress _to = to;
        euint32 _amount = amount;

        _beforeTokenTransferEncrypted(_from, _to, _amount);

        _balancesEncrypted[_from] = TFHE.sub(_balancesEncrypted[_from], _amount);
        _balancesEncrypted[_to] = TFHE.add(_balancesEncrypted[_to], _amount);
        emit TransferEncrypted(_from, _to);
        _tokenCompliance.transferred(_from, _to, _amount);
        return true;
    }

    /**
     *  @notice ERC-20 overridden function that include logic to check for trade validity.
     *  Require that the msg.sender and to addresses are not frozen.
     *  Require that the value should not exceed available balance .
     *  Require that the to address is a verified address
     *  @param _to The address of the receiver
     *  @param _amount The number of tokens to transfer
     *  @return `true` if successful and revert if unsuccessful
     */
    function transfer(eaddress _to, euint32 _amount) public whenNotPaused returns (bool) {
        euint4 ZERO = TFHE.asEuint4(0);
        euint4 ONE = TFHE.asEuint4(1);

        from = TFHE.asEaddress(msg.sender);
        to = _to;
        amount = _amount;

        // A potential workaround having to decrypto these values
        // require(!_frozenEncrypted[_to] && !_frozenEncrypted[msg.sender], "wallet is frozen");
        // The array has the following structure:
        // lenght = 2
        // p0 - contains the function selector, which can be either `transferEncrypted` or `revertThis`
        // p1 - contains the main function selector one of the requirements fails
        // The function inputs are stored in global variables, similarly error messages
        bytes4 revertSelector = bytes4(keccak256(bytes("_revertTransferEncrypted")));
        bytes4 transferSelector = bytes4(keccak256(bytes("_transferEncrypted")));

        selectors[ONE] = revertSelector;
        selectors[ZERO] = revertSelector;

        ebool isRevertable = TFHE.and(TFHE.not(_frozenEncrypted[_to]), TFHE.not(_frozenEncrypted[from]));
        euint4 pos = TFHE.select(isRevertable, ONE, ZERO);
        selectors[pos] = transferSelector;
        revertMessage = "wallet is frozen";

        // Similarly
        // require(_amount <= balanceOf(msg.sender) - (_frozenTokens[msg.sender]), "Insufficient Balance");
        isRevertable = TFHE.le(
            _amount,
            TFHE.sub(TFHE.asEuint32(balanceOf(msg.sender)), TFHE.asEuint32((_frozenTokens[msg.sender])))
        );
        pos = TFHE.select(isRevertable, ONE, ZERO);
        selectors[pos] = transferSelector;
        revertMessage = "Insufficient Balance";

        isRevertable = TFHE.and(
            TFHE.asEbool(_tokenIdentityRegistry.isVerified(_to)),
            _tokenCompliance.canTransfer(TFHE.asEaddress(msg.sender), _to, _amount)
        );
        pos = TFHE.select(isRevertable, ONE, ZERO);
        selectors[pos] = transferSelector;

        (bool success, ) = address(this).call(abi.encodeWithSelector(selectors[ONE]));

        require(success, "Function call failed");
        _tokenCompliance.transferred(from, _to, _amount);

        return success;
    }

    function mint(address _to, uint256 _amount) public override onlyAgent {
        // require(_tokenIdentityRegistry.isVerified(_to), "Identity is not verified.");
        require(_tokenCompliance.canTransfer(address(0), _to, _amount), "Compliance not followed");
        _mint(_to, _amount);
        _tokenCompliance.created(_to, _amount);
    }

    function burn(address _userAddress, uint256 _amount) public override onlyAgent {
        require(balanceOf(_userAddress) >= _amount, "cannot burn more than balance");
        uint256 freeBalance = balanceOf(_userAddress) - _frozenTokens[_userAddress];
        if (_amount > freeBalance) {
            uint256 tokensToUnfreeze = _amount - (freeBalance);
            _frozenTokens[_userAddress] = _frozenTokens[_userAddress] - (tokensToUnfreeze);
            emit TokensUnfrozen(_userAddress, tokensToUnfreeze);
        }
        _burn(_userAddress, _amount);
        _tokenCompliance.destroyed(_userAddress, _amount);
    }

    function setAddressFrozen(address _userAddress, bool _freeze) public override onlyAgent {
        _frozen[_userAddress] = _freeze;

        emit AddressFrozen(_userAddress, _freeze, msg.sender);
    }

    function freezePartialTokens(address _userAddress, uint256 _amount) public override onlyAgent {
        uint256 balance = balanceOf(_userAddress);
        require(balance >= _frozenTokens[_userAddress] + _amount, "Amount exceeds available balance");
        _frozenTokens[_userAddress] = _frozenTokens[_userAddress] + (_amount);
        emit TokensFrozen(_userAddress, _amount);
    }

    function unfreezePartialTokens(address _userAddress, uint256 _amount) public override onlyAgent {
        require(_frozenTokens[_userAddress] >= _amount, "Amount should be less than or equal to frozen tokens");
        _frozenTokens[_userAddress] = _frozenTokens[_userAddress] - (_amount);
        emit TokensUnfrozen(_userAddress, _amount);
    }

    function setIdentityRegistry(address _identityRegistry) public override onlyOwner {
        _tokenIdentityRegistry = IIdentityRegistry(_identityRegistry);
        emit IdentityRegistryAdded(_identityRegistry);
    }

    function setCompliance(address _compliance) public override onlyOwner {
        if (address(_tokenCompliance) != address(0)) {
            _tokenCompliance.unbindToken(address(this));
        }
        _tokenCompliance = ICompliance(_compliance);
        _tokenCompliance.bindToken(address(this));
        emit ComplianceAdded(_compliance);
    }

    function balanceOf(address _userAddress) public view override returns (uint256) {
        return _balances[_userAddress];
    }

    function _transfer(address _from, address _to, uint256 _amount) internal virtual {
        require(_from != address(0), "ERC20: transfer from the zero address");
        require(_to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(_from, _to, _amount);

        _balances[_from] = _balances[_from] - _amount;
        _balances[_to] = _balances[_to] + _amount;
        emit Transfer(_from, _to, _amount);
    }

    function _mint(address _userAddress, uint256 _amount) internal virtual {
        require(_userAddress != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), _userAddress, _amount);

        _totalSupply = _totalSupply + _amount;
        _balances[_userAddress] = _balances[_userAddress] + _amount;
        emit Transfer(address(0), _userAddress, _amount);
    }

    function _burn(address _userAddress, uint256 _amount) internal virtual {
        require(_userAddress != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(_userAddress, address(0), _amount);

        _balances[_userAddress] = _balances[_userAddress] - _amount;
        _totalSupply = _totalSupply - _amount;
        emit Transfer(_userAddress, address(0), _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal virtual {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    // solhint-disable-next-line no-empty-blocks
    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal virtual {}
    function _beforeTokenTransferEncrypted(eaddress _from, eaddress _to, euint32 _amount) internal virtual {}
}
