// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/// OpenTribunal allows an official party to open a court and register a jury via their
/// ethereum addresses and rule the case based on the judge's arguments (guilty or not guilty).
/// Once the case is ruled, the judge signs the decision and the case is closed.
///
/// There are 25 jury members, chosen randomly in a pool of registered and verified
/// persons. The official party has a secured vault containing information to trace back the address
/// to its owner if needed. All jury members will vote, or the police will come and encourage the vote.
contract Court is Ownable {

    address public immutable judge;
    bool public closed = false;
    bool public decision = false;
    uint8 public numberOfVotes = 0;
    uint8 public jurySize = 25;
    uint128 public immutable judgePublicKey;
    // RSA public parameter N
    uint240 public constant N = 0x19502e64b3deff07b8378ff53d5799d9843c63cb871640c11196b500001;
    address[25] public jury;
    string public caseDescription;
    string public judgeArguments;

    struct Vote {
        bool choice;
        bool voted;
    }

    mapping (address => Vote) public juryVote;

    struct Signature {
        uint256 sig;
        address judge;
        bool decision;
        string caseDescription;
    }

    constructor(address _judge, uint128 _judgePublicKey, address[25] memory _jury, string memory _caseDescription, string memory _judgeArguments) {
        judge = _judge;
        judgePublicKey = _judgePublicKey;
        jury = _jury;
        caseDescription = _caseDescription;
        judgeArguments = _judgeArguments;
    }

    modifier caseClosed() {
        require(closed, "Case is closed");
        _;
    }

    modifier caseOpen() {
        require(!closed, "Case is still open");
        _;
    }

    modifier isJury() {
        require(_juryCheck(msg.sender));
        _;
    }

    modifier hasNotVoted() {
        require(!juryVote[msg.sender].voted, "You already voted");
        _;
    }

    /// @notice check that _address is in the jury
    function _juryCheck(address _address) private view returns (bool) {

        for(uint8 i = 0; i < jurySize; i++) {
            if(jury[i] == _address) {
                return true;
            }
        }

        return false;
    }

    /// @notice Each jury member can vot eon the case
    ///         the decision is guilty (true) or not guilty (false)
    function vote(bool _choice) external caseOpen isJury hasNotVoted {
        juryVote[msg.sender].choice = _choice;
        juryVote[msg.sender].voted = true;
        numberOfVotes++;

        if (numberOfVotes == jurySize) {
            //Take decision and close the case
            uint8 guilty = 0;
            uint8 notGuilty = 0;
            for(uint8 i = 0; i < jurySize; i++) {
                if(juryVote[jury[i]].choice) {
                    guilty++;
                } else {
                    notGuilty++;
                }
            }

            decision = guilty > notGuilty;
            closed = true;
        }
    }

    /// @notice fastexp with mod
    function fastExpMod(uint160 _base, uint128 _exponent, uint240 _mod) private pure returns (uint256) {
        uint128 currentExp = _exponent;
        uint256 currentValue = _base;

        if (_exponent == 0) {
            return 1;
        }

        while (currentExp > 1) {
            if (currentExp % 2 == 0) {
                currentValue = currentValue * currentValue % _mod;
                currentExp /= 2;
            } else {
                currentValue = currentValue * _base % _mod;
                currentExp--;
            }
        }
        
        return currentValue;
    }


    /// @notice get a signed version (by the judge) of the resolved case
    function RSAsign() caseClosed external view returns(Signature memory) {
        bytes20 h = bytes20(keccak256(abi.encodePacked(judge, decision, caseDescription)));
        uint256 sig = fastExpMod(uint160(h), judgePublicKey, N);
        return Signature(sig, judge, decision, caseDescription);
    }
}

contract Chainbunal is Ownable {

    Court[] public courts;

    function openCourt(address _judge, uint128 _judgePublicKey, address[25] memory _jury, string memory _caseDescription, string memory _judgeArguments) external onlyOwner returns (Court){
        Court newCourt = new Court(_judge, _judgePublicKey, _jury, _caseDescription, _judgeArguments);
        courts.push(newCourt);
        return newCourt;
    }
}