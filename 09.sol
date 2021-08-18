// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @notice This wallet can be used to store ETH for the owner
///         and send it to another address, with or without payload
contract Wallet {
    address public owner;
    event TransferToWallet(uint256 amount, uint256 total);

    constructor() {
        owner = tx.origin;
    }

    modifier onlyOwner() {
        require(tx.origin == owner);
        _;
    }

    /// @notice transfer the controll of the wallet to a new address
    function transferOwnership(address _newOwner) external onlyOwner{
        owner = _newOwner;
    }

    /// @notice send ETH to an other address
    function send(uint256 _amount, address payable _recipient) external onlyOwner {
        require(_amount <= address(this).balance, "Not enough ETH in wallet");
        _recipient.transfer(_amount);
    }

    /// @notice send ETH to an other address along with a customizable payload
    function sendWithPayload(uint256 _amount, address payable _recipient, bytes calldata _payload) external onlyOwner {
        require(_amount <= address(this).balance, "Not enough ETH in wallet");
        (bool success,) = _recipient.call{value: _amount}(_payload);
        require(success);
    }

    /// @notice used to fund the contract
    function transferToWallet() external payable onlyOwner {
        emit TransferToWallet(msg.value, address(this).balance);
    }
}