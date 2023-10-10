// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Marketplace} from "contracts/facets/MarketplaceFacet.sol";
import "./Helpers.sol";

contract MarketPlaceTest is Helpers {
    Marketplace mPlace;
    CHIXNFT chix;

    uint256 currentCatId;

    address signer1;
    address signer2;

    uint256 privKeyA;
    uint256 privKeyB;

    Marketplace.Catalogue c;

    function setUp() public {
        mPlace = new Marketplace();
        chix = new CHIXNFT();

        (signer1, privKeyA) = mkaddr("signer1");
        (signer2, privKeyB) = mkaddr("signer2");

        c = Marketplace.Catalogue({
            nftAddress: address(chix),
            tokenId: 1,
            price: 1 ether,
            signature: bytes(""),
            deadline: 0,
            creator: address(0),
            active: false
        });

        // mint NFT
        chix.mint(signer1, 1);
    }

    function testOnlyOwnerCanCreateCatalogue() public {
        changeSigner(signer2);

        vm.expectRevert(bytes("NOt the owner"));
        mPlace.createCatalogue(c);
    }

    function testNonApprovedNFT() public {
        changeSigner(signer1);
        vm.expectRevert(bytes("You don't have approval to sell this nft"));
        mPlace.createCatalogue(c);
    }


    function testPriceTooLow() public {
        changeSigner(signer1);
        chix.setApprovalForAll(address(mPlace), true);
        c.price = 0;
        vm.expectRevert(bytes("Low price"));
        mPlace.createCatalogue(c);
    }


    function testMinDuration() public {
        changeSigner(signer1);
        chix.setApprovalForAll(address(mPlace), true);
        vm.expectRevert(bytes("Deadline too short"));
        mPlace.createCatalogue(c);
    }

    function testValidSig() public {
        changeSigner(signer1);
        chix.setApprovalForAll(address(mPlace), true);
        c.deadline = uint88(block.timestamp + 90 minutes);
        c.signature = createSig(
            c.nftAddress,
            c.tokenId,
            c.price,
            c.deadline,
            c.creator,
            privKeyB
        );
        vm.expectRevert(bytes("Invalid signsture"));
        mPlace.createCatalogue(c);
    }

    // EDIT LISTING
    function testEditNonValidCatalogue() public {
        changeSigner(signer1);
        vm.expectRevert(bytes("Catalogue does not exist"));
        mPlace.editCatalogue(1, 0, false);
    }

    function testEditCatalogueNotOwner() public {
        changeSigner(signer1);
        chix.setApprovalForAll(address(mPlace), true);
        c.deadline = uint88(block.timestamp + 120 minutes);
        c.signature = createSig(
            c.nftAddress,
            c.tokenId,
            c.price,
            c.deadline,
            c.creator,
            privKeyA
        );

        uint256 cId = mPlace.createCatalogue(c);

        changeSigner(signer2);
        vm.expectRevert(bytes("You are not the owner"));
        mPlace.editCatalogue(cId, 0, false);
    }

    function testEditListing() public {
        changeSigner(signer1);
        chix.setApprovalForAll(address(mPlace), true);
        c.deadline = uint88(block.timestamp + 120 minutes);
        c.signature = createSig(
            c.nftAddress,
            c.tokenId,
            c.price,
            c.deadline,
            c.creator,
            privKeyA
        );
        uint256 cId = mPlace.createCatalogue(c);
        mPlace.editCatalogue(cId, 0.01 ether, false);


        Marketplace.Catalogue memory edit = mPlace.getCatalogue(cId);
        assertEq(edit.price, 0.01 ether);
        assertEq(edit.active, false);
    }

    // EXECUTE CATALAGUE
    function testExecuteNonValidCatalogue() public {
        changeSigner(signer1);
        vm.expectRevert(bytes("Catalogue does not exist"));
        mPlace.executeCatalogue(1);
    }

    function testExecuteExpiredCatalogue() public {
        changeSigner(signer1);
        chix.setApprovalForAll(address(mPlace), true);
    }

    function testExecuteCatalogueNotActive() public {
        changeSigner(signer1);
        chix.setApprovalForAll(address(mPlace), true);
        c.deadline = uint88(block.timestamp + 120 minutes);
        c.signature = createSig(
            c.nftAddress,
            c.tokenId,
            c.price,
            c.deadline,
            c.creator,
            privKeyA
        );
        uint256 cId = mPlace.createCatalogue(c);
        mPlace.editCatalogue(cId, 0.01 ether, false);
        changeSigner(signer2);
        vm.expectRevert(bytes("Inactive catalogue"));
        mPlace.executeCatalogue(cId);
    }

    function testExecuteInappropriatePrice() public {
        changeSigner(signer1);
        chix.setApprovalForAll(address(mPlace), true);
        c.deadline = uint88(block.timestamp + 120 minutes);
        c.signature = createSig(
            c.nftAddress,
            c.tokenId,
            c.price,
            c.deadline,
            c.creator,
            privKeyA
        );
        uint256 cId = mPlace.createCatalogue(c);
        changeSigner(signer2);
        vm.expectRevert(bytes("Inappriopriate price"));
        mPlace.executeCatalogue{value: 0.9 ether}(cId);
    }

   

    function testExecute() public {
        changeSigner(signer1);
        chix.setApprovalForAll(address(mPlace), true);
        c.deadline = uint88(block.timestamp + 120 minutes);
        // l.price = 1 ether;
        c.signature = createSig(
            c.nftAddress,
            c.tokenId,
            c.price,
            c.deadline,
            c.creator,
            privKeyA
        );
        uint256 cId = mPlace.createCatalogue(c);
        changeSigner(signer2);
        uint256 signer1BalanceBefore = signer1.balance;

        mPlace.executeCatalogue{value: c.price}(cId);

        uint256 signer1BalanceAfter = signer1.balance;

        Marketplace.Catalogue memory sale = mPlace.getCatalogue(cId);
        assertEq(sale.price, 1 ether);
        assertEq(sale.active, false);

        assertEq(sale.active, false);
        assertEq(ERC721(c.nftAddress).ownerOf(c.tokenId), signer2);
        assertEq(signer1BalanceAfter, signer1BalanceBefore + c.price);
    }
}
