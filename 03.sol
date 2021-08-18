// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

// A new kind of insurance companies emerges,
// no more direct responsibility on a car crash !!
// The one who will get a new car is the most hardworking
// hash function cracker
library Hashlib {
    /// @notice Hash the value _toHash
    function hash(bytes32 _toHash) public  pure returns (bytes32) {
        uint128 left = uint128(bytes16(_toHash));
        uint128 right = uint128(uint256(_toHash));
        uint128 temp1 = left;
        left = left ^ right;
        right = left ^ temp1;

        uint128 mask1 = 0xf0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0;
        uint128 mask2 = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f;
        uint128 temp2 = right;
        right = left ^ mask1;
        left = temp2 ^ mask2;
        
        return bytes32(uint(left ^ right ^ ~mask2 ^ ~mask1) << 0x80 | uint(left ^ ~mask1));
    }
}

contract AccidentFormFiller is Ownable {

    struct Report {
        address driver1;
        address driver2;
        bytes32 value;
        bytes32 answer;
        address winner;
        bool caseClosed;
        string comments;
    }

    bytes32 public value;
    address public driver1;
    address public driver2;
    string public comments;
    Report public report;
    
    modifier caseOpen() {
        require(!report.caseClosed, "Case is closed");
        _;
    } 

    /// @notice Fill the report with basic information
    function writeReport() public caseOpen {
        report = Report(driver1, driver2, value, 0, address(0), false, comments);
    }

    /// @notice Fill the remaining fields of the report and mark it as case closed
    function closeReport(bytes32 _answer, address _winner) public caseOpen {
        report.answer = _answer;
        report.winner = _winner;
        report.caseClosed = true;
    }
}

contract CarCrash is Ownable {

    using Hashlib for bytes32;

    struct Report {
        address driver1;
        address driver2;
        bytes32 value;
        bytes32 answer;
        address winner;
        bool caseClosed;
        string comments;
    }

    bytes32 public value;
    address public driver1;
    address public driver2;
    string public comments;
    Report public report;
    AccidentFormFiller public filler;
    address public winner;

    event CaseClosed(address winnner);

    constructor(bytes32 _value, address _driver1, address _driver2, string memory _comments, AccidentFormFiller _filler) {
        value = _value;
        driver1 = _driver1;
        driver2 = _driver2;
        comments = _comments;
        filler = _filler;
        
        // Fill the fields with availabe information
        (bool res,) = address(_filler).delegatecall(abi.encodeWithSignature("writeReport()"));
        require(res);
    }

    modifier onlyDrivers {
        require(msg.sender == driver1 || msg.sender == driver2, "Only concerned drivers can attempt");
        _;
    }
    
    modifier caseOpen() {
        require(!report.caseClosed, "Case is closed");
        _;
    } 

    /// @notice Each driver can try to crack the hash, the first one who crack it
    ///         wins the case and won't have to pay for the damages.
    function attempt(bytes32 _attempt) external onlyDrivers caseOpen returns (bool) {

        if (_attempt.hash() == value){
            winner = msg.sender; 
            (bool res,) = address(filler).delegatecall(abi.encodeWithSignature("closeReport(bytes32,address)", _attempt, winner));
            require(res);
            emit CaseClosed(winner);
            return true;
        }

        return false;
    }
}

contract InsuranceCompany is Ownable {

    CarCrash[] cases;
    mapping (bytes32 => bool) oldValues;
    
    function resolveResponsibility(bytes32 _value, address _driver1, address _driver2, string calldata _comments, AccidentFormFiller _filler) external onlyOwner returns (CarCrash) {
        require(!oldValues[_value]);
        oldValues[_value] = true;
        CarCrash newCase = new CarCrash(_value, _driver1, _driver2, _comments, _filler);
        cases.push(newCase);
        return newCase;
    }
}
// Works well with value 0x646f6e277420646f20796f7572206f776e2063727970746f0000000000000000