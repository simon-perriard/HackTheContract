// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface ProductI {
    struct Product {
        string description;
        address seller;
        address buyer;
        uint256 auctionPrice;
        uint256 directBuyPrice;
        uint256 finalPrice;
        uint256 timeLimitForAuction;
        bool isSold;
    }
}

interface BlockScout24Buyer is ProductI {
    function price(Product calldata _product) external returns (uint256);
}

/// @notice this contract can be used to sell and buy products, by auctions or direct buy.
///         This contracts only deals with the price agreement. Actual sales happen in an other contract
///         where the buyer will have to pay finalPrice for the product, and the seller will have to send it.
contract BlockScout24 is Ownable, ProductI {
    
    Product[] public products;

    /// @notice a customer can raise the auction on a product or buy it directly for a fixed price
    function buyProduct(uint256 _productId) external {
        // Check that ID is valid and product not already sold
        // or time limit for auction is not over
        require(_productId < products.length, "Invalid product ID");
        require(!products[_productId].isSold, "Product already sold");
        require(products[_productId].timeLimitForAuction >= block.timestamp,
                "Auction has ended.");

        // Check that the price announced by the buyer is at least auctionPrice+1
        require(BlockScout24Buyer(msg.sender).price(products[_productId]) > products[_productId].auctionPrice,
                "Your price is too low.");

        if (BlockScout24Buyer(msg.sender).price(products[_productId]) >= products[_productId].directBuyPrice) {
            // Direct buy
            products[_productId].isSold = true;
            products[_productId].finalPrice = BlockScout24Buyer(msg.sender).price(products[_productId]);
            products[_productId].buyer = msg.sender;
        } else {
            // Raise auction price
            products[_productId].auctionPrice = BlockScout24Buyer(msg.sender).price(products[_productId]);
            products[_productId].buyer = msg.sender;
        }
    }

    /// @notice anyone can mark the product as sold when the auction has ended
    function validateAuction(uint256 _productId) external {
        require(_productId < products.length, "Invalid product ID");
        require(!products[_productId].isSold, "Product already sold");
        require(products[_productId].timeLimitForAuction < block.timestamp, "The auction has not ended yet.");

        products[_productId].isSold = true;
        products[_productId].finalPrice = products[_productId].auctionPrice;
    }

    /// @notice used by sellers when one wants to sell a new product
    function addProduct(string calldata _description, uint256 _auctionPrice, uint256 _directBuyPrice) external {
        products.push(Product(_description,
                                msg.sender,
                                address(0x0),
                                _auctionPrice,
                                _directBuyPrice,
                                0,
                                block.timestamp + 2 weeks,
                                false));
    }
}