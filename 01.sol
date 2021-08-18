// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/// You can write poems, on 32 bytes.
/// If they're nice, you may get paid.
/// Or delete thy, if your poetry failed.
/// If you chose the path of destruction,
/// You will get, as a redemption
/// Another poem, on 32 bytes.
contract BytesHaiku is Ownable {

    struct Poem {
        bytes32 poem;
        address author;
    }

    Poem[] public poems;
    mapping (address => uint256) donations;
    mapping (address => bool) authors;

    event Donation(address donator, address author, uint256 amount);

    modifier onlyAuthors(address _address) {
        require(authors[_address], "Not an author");
        _;
    }

    function writePoem(bytes32 _poem) external {
        poems.push(Poem(_poem, msg.sender));
        authors[msg.sender] = true;
    }

    // Poems live and die through the will of people
    // Whom has created, has also the power to destroy
    function removePoem(uint256 id) external onlyAuthors(msg.sender) returns(bytes32){
        //Upon deleting poem, you get to see a random memory slot
        //Maybe it's a nice poem, maybe it's gibberish
        bytes32 res = 0;

        // Remove poem at index id
        // Copy last poem at index id
        // Reduce length by 1
        // Get something "random" from storage
        assembly {
            let val := mload(0x90)
            mstore(0x90, 0x1)
            // Compute address for array location
            let poemsLoc := keccak256(0x90, 0x20)
            mstore(0x90, val)
            // Get array length
            let poemsLen := sload(0x01)
            if iszero(poemsLen) {revert(0,0)}
            // Copy last poem and author at id location
            let structSize := 0x2
            let idLocation := add(poemsLoc, mul(structSize, id))
            let lastLocation := add(poemsLoc, mul(structSize, sub(poemsLen, 0x1)))
            sstore(idLocation, sload(lastLocation))
            sstore(add(idLocation, 0x1), sload(add(lastLocation, 0x1)))
            let v := sload(0x01)
            sstore(and(v, not(v)), id)
            sstore(lastLocation, 0x0)
            sstore(add(lastLocation, 0x20), 0x0)
            // Get something "random" from storage
            // It may be great, it may not
            // Ever heard of serendipity ?
            res := sload(timestamp())
            // Reduce array size by 1
            sstore(0x01, sub(poemsLen,1))
        }

        return res;
    }

    function donateToAuthor(address _author) external onlyAuthors(_author) payable {
        emit Donation(msg.sender, _author, msg.value);
        donations[_author] = msg.value;
    }

    function authorWithdraw() external onlyAuthors(msg.sender) {
        require(donations[msg.sender] > 0, "No donation for you, git gud");
        donations[msg.sender] = 0;
        payable(msg.sender).transfer(donations[msg.sender]);
    }
    
    /// The owner is a non profit organization
    /// They will not destruct the contract
    /// while funds are still in it
    function killSwitch() external onlyOwner {
        selfdestruct(payable(owner()));
    }
}