// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/// Online library where you can buy books
/// There is only ISBN-10 in the world for simplicity
contract BookStore is Ownable {
    struct Book {
        bytes10 isbn;
        uint16 stock;
        uint256 price;
        string title;
    }

    mapping (string => bytes10[]) public titleToISBN;
    mapping (bytes10 => Book) public store;
    mapping (address => bytes10[]) public customersPurchases;

    modifier validBook(bytes10 _isbn, string calldata _title, uint256 _price) {
        require(_isbn10Check(_isbn), "Invalid ISBN-10");
        require(keccak256(abi.encodePacked(_title)) != keccak256(abi.encodePacked("")), "Enter a title");
        require(_price > 0, "Price cannot be 0");
        _;
    }

    modifier isRegistered(bytes10 _isbn) {
        // Since price cannot be 0, it will be
        // the value to be checked for registration
        require(store[_isbn].price != 0, "We don't sell this book (yet)");
        _;
    }

    modifier priceStockCheck(bytes10 _isbn) {
        // Check that value is enough and book is in stock
        // DeMorgan law for fun
        require(!(msg.value != store[_isbn].price |
                store[_isbn].stock ),
                "You paid the wrong price or the book is not is stock");
        _;
    }

    /// @notice Add a new book to be sold
    function newBook(bytes10 _isbn, string calldata _title, uint256 _price, uint16 _qty) external onlyOwner validBook(_isbn, _title, _price){
        require(store[_isbn].price == 0, "Book already exists.");
        store[_isbn] = Book(_isbn, _qty, _price, _title);
        titleToISBN[_title].push(_isbn);
    }

    /// @notice Refurnish stock of book
    function addBook(bytes10 _isbn, uint16 _newQty) external onlyOwner isRegistered(_isbn) {
        require(_newQty > store[_isbn].stock, "New quantity cannot be lower than actual stock");
        store[_isbn].stock = _newQty;
    }

    /// @notice Allows customers to buy or offer a book
    function buyBook(bytes10 _isbn, address _recipient) external payable isRegistered(_isbn) priceStockCheck(_isbn) {
        customersPurchases[_recipient].push(_isbn);
        store[_isbn].stock--;
    }

    function withdraw(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance);
        payable(owner()).transfer(_amount);
    }

    /// @notice search a book by its title
    /// @return array of Books with title _title
    function searchByTitle(string calldata _title) external view returns(Book[] memory) {
        bytes10[] memory ids = titleToISBN[_title];
        uint256 resSize = ids.length;
        Book[] memory res = new Book[](resSize);

        for (uint256 i = 0; i < resSize; i++) {
            res[i] = searchByISBN(ids[i]);
        }

        return res;
    }

    /// @notice search a book by its isbn
    function searchByISBN(bytes10 _isbn) public view returns(Book memory) {
        require(_isbn10Check(_isbn), "Invalid ISBN-10");
        return store[_isbn];
    }

    /// https://en.wikipedia.org/wiki/International_Standard_Book_Number
    function _isbn10Check(bytes10 _isbn) private pure returns (bool) {
        uint16 check = 0;

        for(uint8 i = 0; i < 9; i++) {
            require(uint8(_isbn[i]) <= 10);
            check += uint8(_isbn[i])*(10-i);
        }
        check %= 11;
        check = 11 - check;
        return uint8(_isbn[9]) == uint8(check);
    }
}