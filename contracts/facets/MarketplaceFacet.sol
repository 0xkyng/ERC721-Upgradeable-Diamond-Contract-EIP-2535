// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LibDiamond, Order} from "../libraries/LibDiamond.sol";
import {LibSign} from "../libraries/LibSign.sol";

import "contracts/facets/ERC721Facet.sol";

contract Marketplace {
    /* ERRORS */
    error NotOwner();
    error NotApproved();
    error MinPriceTooLow();
    error DeadlineTooSoon();
    error MinDurationNotMet();
    error InvalidSignature();
    error OrderNotExistent();
    error OrderNotActive();
    error PriceNotMet(int256 difference);
    error OrderExpired();
    error PriceMismatch(uint256 originalPrice);

    /* EVENTS */
    event OrderCreated(uint256 indexed orderId, Order);
    event OrderExecuted(uint256 indexed orderId, Order);
    event OrderEdited(uint256 indexed orderId, Order);

    constructor() {}

    function createOrder(Order calldata l) public returns (uint256 lId) {
        if (NFTFacet(l.token).ownerOf(l.tokenId) != msg.sender)
            revert NotOwner();
        if (!NFTFacet(l.token).isApprovedForAll(msg.sender, address(this)))
            revert NotApproved();
        if (l.price < 0.01 ether) revert MinPriceTooLow();
        if (l.deadline < block.timestamp) revert DeadlineTooSoon();
        if (l.deadline - block.timestamp < 60 minutes)
            revert MinDurationNotMet();

        // Assert signature
        if (
            !LibSign.isValid(
                LibSign.constructMessageHash(
                    l.token,
                    l.tokenId,
                    l.price,
                    l.deadline,
                    l.owner
                ),
                l.signature,
                msg.sender
            )
        ) revert InvalidSignature();

        // append to Storage
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        Order storage li = ds.mOrders[ds.mOrderId];
        li.token = l.token;
        li.tokenId = l.tokenId;
        li.price = l.price;
        li.signature = l.signature;
        li.deadline = uint88(l.deadline);
        li.owner = msg.sender;
        li.active = true;

        // Emit event
        emit OrderCreated(ds.mOrderId, l);
        lId = ds.mOrderId;
        ds.mOrderId++;
        return lId;
    }

    function executeOrder(uint256 _orderId) public payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (_orderId >= ds.mOrderId) revert OrderNotExistent();
        Order storage order = ds.mOrders[_orderId];
        if (order.deadline < block.timestamp) revert OrderExpired();
        if (!order.active) revert OrderNotActive();
        if (order.price < msg.value) revert PriceMismatch(order.price);
        if (order.price != msg.value)
            revert PriceNotMet(int256(order.price) - int256(msg.value));

        // Update state
        order.active = false;

        // transfer
        NFTFacet(order.token).transferFrom(
            order.owner,
            msg.sender,
            order.tokenId
        );

        // transfer eth
        payable(order.owner).transfer(order.price);

        // Update storage
        emit OrderExecuted(_orderId, order);
    }

    function editOrder(
        uint256 _orderId,
        uint256 _newPrice,
        bool _active
    ) public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (_orderId >= ds.mOrderId) revert OrderNotExistent();
        Order storage order = ds.mOrders[_orderId];
        if (order.owner != msg.sender) revert NotOwner();
        order.price = _newPrice;
        order.active = _active;
        emit OrderEdited(_orderId, order);
    }

    // add getter for order
    function getOrder(uint256 _orderId) public view returns (Order memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        // if (_orderId >= orderId)
        return ds.mOrders[_orderId];
    }
}