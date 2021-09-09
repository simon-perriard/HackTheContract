// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/// Simply a rock-paper-scissors game with a commitment scheme to avoid front-running attacks. 
/// 1 (FUNDING state). Both players must first fund the game with the agreedStake amount
/// 2 (COMMITMENT state). Then they will commit to their action ("ROCK", "PAPER" or "SCISSORS")
/// 3 (REVEAL state). When both have committed, they will reveal their action and the winner is designated.
///                     In the case of a draw, goto 2.
/// 4 (WON state). The winner can withdraw his prise.
/// 5 (FINISHED state). The owner can kill the contract, any remaining funds are sent to the owner.
contract RockPaperScissors is Ownable {

    enum GameState {FUNDING, COMMITMENT, REVEAL, WON, FINISHED, STALLED}
    GameState public currentState = GameState.FUNDING;

    address public immutable player1;
    address public immutable player2;
    address public winner;
    uint256 public immutable agreedStake;
    uint256 public immutable creationTime;

    struct PlayerState {
        uint stake;
        bytes32 commitment;
        string action;
    }

    mapping (address => PlayerState) public playerStates;

    event GameStart(address player1, address player2, uint256 stake);
    event PlayerCommitted(address player);
    event PlayerRevealed(address player);
    event Liar(address player);
    event Draw(string action);
    event Winner(address winner);

    bytes32 public constant ROCK = keccak256(abi.encodePacked("ROCK"));
    bytes32 public constant PAPER = keccak256(abi.encodePacked("PAPER"));
    bytes32 public constant SCISSORS = keccak256(abi.encodePacked("SCISSORS"));

    constructor(address _player1, address _player2, uint256 _agreedStake) {
        require(_player1 != address(0) && _player2 != address(0), "Invalid player address (0x0)");

        creationTime = block.timestamp;

        // Limit the amount at stake, otherwise withdraw() could overflow and revert, and winner never gets paid
        uint maxStake;
        unchecked {
            maxStake = (uint256(0)-1)/2;
        }
        require(_agreedStake <= maxStake, "Too much at stake");
        player1 = _player1;
        player2 = _player2;
        agreedStake = _agreedStake;

        PlayerState memory newPlayer = PlayerState(0, "0x0", "");
        playerStates[_player1] = newPlayer;
        playerStates[_player2] = newPlayer;
    }

    modifier onlyPlayers() {
        require(msg.sender == player1 || msg.sender == player2, "Non players cannot interact with the game.");
        _;
    }

    modifier stateCheck(GameState _state) {
        require(currentState == _state, "Please check the state of the game");
        _;
    }

    // Players have 1 week to go through the COMMITMENT and REVEAL states, after this time
    // they can get back their amount at stake
    modifier stateCheckWithStall(GameState _state) {
        require(currentState == _state ||
                currentState == GameState.STALLED ||
                block.timestamp > creationTime + 1 weeks,
                "Either it is too soon or the game is not finished.");
        _;
    }

    modifier actionIsValid(bytes32 _action) {
        require(_action == ROCK ||
                _action == PAPER || 
                _action == SCISSORS,
                "Your action is invalid: choose between ROCK, PAPER and SCISSORS");
        _;
    }

    /// @notice both players must put the amount at stake in the contract
    function fundGame() external payable onlyPlayers stateCheck(GameState.FUNDING) {
        require(msg.value == agreedStake, "The amount must correspond to the agreed stake.");
        require(playerStates[msg.sender].stake == 0, "You already sent your money.");

        playerStates[msg.sender].stake = msg.value;

        // Lock fundings when both players have put amounts at stake
        if (playerStates[player1].stake == agreedStake && playerStates[player2].stake == agreedStake) {
            emit GameStart(player1, player2, agreedStake);
            currentState = GameState.COMMITMENT;
        }
    }

    /// @notice during the FUNDING phase, the players still can withdraw their funds
    function unfundGame() external onlyPlayers stateCheck(GameState.FUNDING) {
        uint refundAmount = playerStates[msg.sender].stake;
        playerStates[msg.sender].stake = 0;
        payable(msg.sender).transfer(refundAmount);
    }

    /// @notice after the FUNDING phase, each player will commit to his action
    function commitToAction(bytes32 _playerCommitment) external onlyPlayers stateCheck(GameState.COMMITMENT) {
        require(playerStates[msg.sender].commitment == bytes32("0x0"), "You already committed.");

        // Store player commitment
        playerStates[msg.sender].commitment = _playerCommitment;

        emit PlayerCommitted(msg.sender);

        if (playerStates[player1].commitment != bytes32("0x0") && playerStates[player2].commitment != bytes32("0x0")) {
            // Go to next state when both committed
            currentState = GameState.REVEAL;
        }
    }

    /// @notice after the COMMITMENT phase, each player will reveal his action, the commitment value is checked, and
    ///         the battle ends with a winner, or a draw
    function reveal(string calldata _action) external onlyPlayers stateCheck(GameState.REVEAL) actionIsValid(keccak256(abi.encodePacked(_action))) {
        if (keccak256(abi.encodePacked(_action)) != playerStates[msg.sender].commitment) {
            // If a player lies on his action, he loses immediately
            emit Liar(msg.sender);
            if (msg.sender == player1) {
                winner = player2;
            } else {
                winner = player1;
            }
            currentState = GameState.WON;
            emit Winner(winner);

            return;
        }

        playerStates[msg.sender].action = _action;

        bytes32 emptyString = keccak256(abi.encodePacked(""));

        bytes32 action1 = keccak256(abi.encodePacked(playerStates[player1].action));
        bytes32 action2 = keccak256(abi.encodePacked(playerStates[player2].action));

        emit PlayerRevealed(msg.sender);

        if (action1 != emptyString && action2 != emptyString) {
            // Both players revealed, time to find the winner

            if (action1 == action2) {
                // In case of a draw, undo commitment and action
                // and revert to COMMITMENT state
                playerStates[player1].commitment = bytes32("0x0");
                playerStates[player2].commitment = bytes32("0x0");

                playerStates[player1].action = "";
                playerStates[player2].action = "";

                currentState = GameState.COMMITMENT;
                emit Draw(_action);

            } else {
                if (action1 == ROCK) {
                    if (action2 == PAPER) {
                        winner = player2;
                    } else {
                        winner = player1;
                    }
                } else if (action1 == PAPER) {
                    if (action2 == ROCK) {
                        winner = player1;
                    } else {
                        winner = player2;
                    }
                } else {
                    // action1 == SCISSORS
                    if (action2 == ROCK) {
                        winner = player2;
                    } else {
                        winner = player1;
                    }
                }
                currentState = GameState.WON;
                emit Winner(winner);
            }
        }
    }

    /// @notice once the winner is designated, the winner can withdraw the prize
    function withdraw() external stateCheck(GameState.WON) {
        playerStates[player1].stake = 0;
        playerStates[player2].stake = 0;

        currentState = GameState.FINISHED;

        payable(winner).transfer(2*agreedStake);
    }

    /// @notice if the game is stalled (one of the players does not reveal) for more thant a week
    ///         the players are allowed to get back their stakes
    function withdrawForStall() external onlyPlayers stateCheckWithStall(GameState.REVEAL) {
        playerStates[msg.sender].stake = 0;
        currentState = GameState.STALLED;

        if (playerStates[player1].stake == 0 && playerStates[player2].stake == 0) {
            currentState = GameState.FINISHED;
        } 

        payable(msg.sender).transfer(agreedStake);
    }

    /// @notice no locked ether
    function withdrawSurplus() external onlyOwner stateCheck(GameState.FINISHED) {
        payable(owner()).transfer(address(this).balance);
    }
}

/// Fabric for rock-paper-scissors games
/// nothing to see here
contract RockPaperScissorsFabric is Ownable {

    function newGame(address _player1, address _player2, uint256 _agreedStake) external onlyOwner returns(address) {
        RockPaperScissors newRPS = new RockPaperScissors(_player1, _player2, _agreedStake);
        return address(newRPS);
    }

    function killGame(address _gameAddress) external onlyOwner {
        RockPaperScissors rps = RockPaperScissors(_gameAddress);
        rps.withdrawSurplus();
    }

    function withdraw(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance);
        payable(msg.sender).transfer(_amount);
    }

    fallback() external payable {}
}