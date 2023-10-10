// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/ERC721Facet.sol";
import "./helpers/DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupeFacet;
    OwnershipFacet ownerFacet;
    ERC721Facet erc721Facet;
    ERC721Facet ERC721_Diamond;

    string name = "ERC721_DIAMOND";
    string symbol = "ECR721";

    address user1 = vm.addr(0x1);
    address user2 = vm.addr(0x2);

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet), name, symbol);
        dLoupeFacet = new DiamondLoupeFacet();
        ownerFacet = new OwnershipFacet();
        erc721Facet = new ERC721Facet();

        ERC721_Diamond = ERC721Facet(address(diamond));
        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupeFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        // erc721Facet
        cut[2] = (
            FacetCut({
                facetAddress: address(erc721Facet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC721Facet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function testERC721Facet_Name() public {
        assertEq(ERC721_Diamond.name(), name);
    }

    function testERC721Facet_Symbol() public {
        assertEq(ERC721_Diamond.symbol(), symbol);
    }

    function testERC721Facet_Balances() public {
        vm.prank(user1);

        uint256 tokenId = 213;
        uint256 tokenId2 = 123;

        ERC721_Diamond.mint(user1, tokenId);


        ERC721_Diamond.mint(user1, tokenId2);

        assertEq(ERC721_Diamond.balanceOf(user1), 2);
    }

    function testERC721Facet_Owner() public {
        vm.prank(user1);

        uint256 tokenId = 213;
        uint256 tokenId2 = 12345;

        ERC721_Diamond.mint(user1, tokenId);

        assertEq(ERC721_Diamond.ownerOf(tokenId), user1);

        vm.prank(user2);
        ERC721_Diamond.mint(user2, tokenId2);

        assertEq(ERC721_Diamond.ownerOf(tokenId2), user2);
    }

    function testERC721Facet_tokenApproval() public {
        uint256 tokenId = 210;
        ERC721_Diamond.mint(user1, tokenId);
        vm.prank(user1);
        ERC721_Diamond.approve(user2, tokenId);

        assertEq(ERC721_Diamond.getApproved(210), user2);
    }

    function testERC721Facet_isApprovedForAll() public {
        uint256 tokenId = 211;
        uint256 tokenId2 = 215;
        ERC721_Diamond.mint(user1, tokenId);
        ERC721_Diamond.mint(user1, tokenId2);

        vm.prank(user1);
        ERC721_Diamond.setApprovalForAll(user2, true);

        assertTrue(ERC721_Diamond.isApprovedForAll(user1, user2));
    }

    function testERC721Facet_Mint() public {
        uint256 tokenId = 211;
        uint256 tokenId2 = 215;
        uint256 tokenId3 = 202345;

        ERC721_Diamond.mint(user1, tokenId);
        ERC721_Diamond.mint(user1, tokenId2);
        ERC721_Diamond.mint(user1, tokenId3);

        assertEq(ERC721_Diamond.balanceOf(user1), 3);
    }

    function testERC721Facet_transferFrom() public {}

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
