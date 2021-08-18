// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/// A rich individual decides to invest his fortune
/// to fund a flashloans smart contract
contract FlashLoaner is Ownable {

    uint256 available = 0;
    // Loan fee is tax/100;
    uint8 feeRate;

    constructor(uint8 _feeRate) payable {
        require(_feeRate >= 0 && _feeRate <= 10);
        available = msg.value;
        feeRate = _feeRate;
    }

    modifier enoughFunds(uint256 _requestedAmount) {
        require(_requestedAmount <= address(this).balance);
        _;
    }

    /// @notice Loans <= 1 ether have offered fees
    function flashLoan(uint256 _requestedAmount, address payable _recipient, bytes memory _callback) external enoughFunds(_requestedAmount) returns (bool){
        uint256 balanceBefore = address(this).balance;
        (bool success,) = _recipient.call{value: _requestedAmount}(_callback);
        bool feeCheck = true;
        if (_requestedAmount > 1 ether) {
            uint256 balanceAfter = address(this).balance;
            feeCheck = balanceAfter == balanceBefore + _requestedAmount * feeRate / 100;
        } 

        success = success && feeCheck;
        require(success);
        
        return feeCheck;
    }

    /// @notice The owner can adapt the fees in a fixed range
    function updateFeeRate(uint8 _newFeeRate) external onlyOwner {
        require(_newFeeRate >= 0 && _newFeeRate <= 10);
        feeRate = _newFeeRate;
    }

    /// @notice Anyone can add money to the contract
    function fund(uint256 _amount) external payable {}

    function withdraw(uint256 _amount) public onlyOwner {
        require(_amount <= address(this).balance);
        payable(owner()).transfer(_amount);
    }
}