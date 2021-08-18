// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

/// Those who can guess the future are rewarded
contract GuessTheFuture {

    uint256 currentGameFunds = 0;

    mapping (address => uint256) winnersPrizes;
    event Donator(address donator, uint256 amount);
    event Winner(address donator, uint256 amount);

    constructor() payable {}

    modifier isNotContract {
        uint256 size;
        assembly {
            size := extcodesize(caller())
        }
        require(size == 0);
        _;
    }

    /// @notice only EOA can play, if the EOA can guess the value, it receives the current amount
    ///         at stake (currentGameFunds). The EOA will have to withdraw himself afterwards.
    function guessTheFuture(uint256 _guess) external payable isNotContract returns (bool) {
        require(msg.value >= 1 ether, "Pay to play");
        uint256 value = block.timestamp ^ block.gaslimit ^ block.number;

        currentGameFunds += msg.value;

        if (value == _guess) {
            winnersPrizes[msg.sender] += currentGameFunds;
            emit Winner(msg.sender, currentGameFunds);
            currentGameFunds = 0;
        }

        return value == _guess;
    }

    /// @notice winners can withdraw their prize here
    function withdraw() external {
        require(winnersPrizes[msg.sender] > 0, "You won zero, nice!");
        uint256 amount = winnersPrizes[msg.sender];
        winnersPrizes[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    /// @notice Anyone can make a donation to the contract
    function donationForTheFuture() public payable {
        if (msg.value > 0) {
            emit Donator(msg.sender, msg.value);
            currentGameFunds += msg.value;
        }
    }

    fallback() external payable {
        donationForTheFuture();
    }

    receive() external payable {
        donationForTheFuture();
    }
}