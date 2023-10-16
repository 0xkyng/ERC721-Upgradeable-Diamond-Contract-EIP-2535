// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../contracts/interfaces/IDiamondCut.sol";
import {Marketplace} from "contracts/facets/MarketplaceFacet.sol";
import "contracts/facets/ERC721Facet.sol";
import "../contracts/libraries/LibDiamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "./helpers/DiamondUtils.sol";
import "./helpers/Helpers.sol";
import "../contracts/Diamond.sol";

contract MarketPlaceTest is Helpers, DiamondUtils, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;

    Marketplace mPlace;
    NFTFacet nft;

    uint256 currentOrderId;

    address userA;
    address userB;

    uint256 privKeyA;
    uint256 privKeyB;

    Order order;

    function setUp() public {
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(
            address(this),
            address(dCutFacet),
            "Blessed",
            "BTK",
            "MyNFT",
            "MNT"
        );
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        nft = new NFTFacet();
        mPlace = new Marketplace();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(nft),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("NFTFacet")
            })
        );

        cut[3] = (
            FacetCut({
                facetAddress: address(mPlace),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("Marketplace")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        (userA, privKeyA) = mkaddr("USERA");
        (userB, privKeyB) = mkaddr("USERB");

        order = Order({
            token: address(nft),
            tokenId: 1,
            price: 1 ether,
            signature: bytes(""),
            deadline: 0,
            owner: address(0),
            active: false
        });

        nft.mint(userA, 1);
    }

    function testOwnerCannotCreateOrder() public {
        order.owner = userB;
        switchSigner(userB);

        vm.expectRevert(Marketplace.NotOwner.selector);
        Marketplace(address(diamond)).createOrder(order);
    }

    function testNFTNotApproved() public {
        switchSigner(userA);
        vm.expectRevert(Marketplace.NotApproved.selector);
        mPlace.createOrder(order);
    }

    function testMinPriceTooLow() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        // NFTFacet(address(diamond)).setApprovalForAll(address(diamond), true);
        order.price = 0;
        vm.expectRevert(Marketplace.MinPriceTooLow.selector);
        mPlace.createOrder(order);
    }

    function testMinDeadline() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        vm.expectRevert(Marketplace.DeadlineTooSoon.selector);
        mPlace.createOrder(order);
    }

    function testMinDuration() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 59 minutes);
        vm.expectRevert(Marketplace.MinDurationNotMet.selector);
        mPlace.createOrder(order);
    }

    function testSignatureNotValid() public {
        // Test that signature is valid
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyB
        );
        vm.expectRevert(Marketplace.InvalidSignature.selector);
        mPlace.createOrder(order);
    }

    // EDIT Order
    function testEditNonValidOrder() public {
        switchSigner(userA);
        vm.expectRevert(Marketplace.OrderNotExistent.selector);
        mPlace.editOrder(1, 0, false);
    }

    function testEditOrderNotOwner() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        uint256 newOrderId = mPlace.createOrder(order);

        switchSigner(userB);
        vm.expectRevert(Marketplace.NotOwner.selector);
        mPlace.editOrder(newOrderId, 0, false);
    }

    function testEditOrder() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        uint256 newOrderId = mPlace.createOrder(order);
        mPlace.editOrder(newOrderId, 0.01 ether, false);

        Order memory _order = mPlace.getOrder(newOrderId);
        assertEq(_order.price, 0.01 ether);
        assertEq(_order.active, false);
    }

    // EXECUTE Order
    function testExecuteNonValidOrder() public {
        switchSigner(userA);
        vm.expectRevert(Marketplace.OrderNotExistent.selector);
        mPlace.executeOrder(1);
    }

    function testExecuteExpiredOrder() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
    }

    function testExecuteOrderNotActive() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        uint256 newOrderId = mPlace.createOrder(order);
        mPlace.editOrder(newOrderId, 0.01 ether, false);
        switchSigner(userB);
        vm.expectRevert(Marketplace.OrderNotActive.selector);
        mPlace.executeOrder(newOrderId);
    }

    function testFulfilOrderPriceNotEqual() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        uint256 newOrderId = mPlace.createOrder(order);
        switchSigner(userB);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.PriceNotMet.selector,
                order.price - 0.9 ether
            )
        );
        mPlace.executeOrder{value: 0.9 ether}(newOrderId);
    }

    function testFulfilOrderPriceMismatch() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        uint256 newOrderId = mPlace.createOrder(order);
        switchSigner(userB);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.PriceMismatch.selector,
                order.price
            )
        );
        mPlace.executeOrder{value: 1.1 ether}(newOrderId);
    }

    function testFulfilOrder() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        order.deadline = uint88(block.timestamp + 120 minutes);
        order.signature = constructSig(
            order.token,
            order.tokenId,
            order.price,
            order.deadline,
            order.owner,
            privKeyA
        );
        uint256 newOrderId = mPlace.createOrder(order);
        switchSigner(userB);
        uint256 userABalanceBefore = userA.balance;

        mPlace.executeOrder{value: order.price}(newOrderId);

        uint256 userABalanceAfter = userA.balance;

        Order memory _order = mPlace.getOrder(newOrderId);
        assertEq(_order.price, 1 ether);
        assertEq(_order.active, false);

        assertEq(_order.active, false);
        assertEq(NFTFacet(order.token).ownerOf(order.tokenId), userB);
        assertEq(userABalanceAfter, userABalanceBefore + order.price);
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}