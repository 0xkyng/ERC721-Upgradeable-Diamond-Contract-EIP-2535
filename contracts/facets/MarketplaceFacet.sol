// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "solmate/tokens/ERC721.sol";

import "openzeppelin/interfaces/IERC721.sol";
// "solmate/tokens/ERC721/IERC721.sol";
import {SignUtils} from "contracts/libraries/SignUtils.sol";

contract Marketplace is ERC721{
    


    /* EVENTS */
    event CreatedCatalogue(uint256 indexed catalogueId, Catalogue);
    event ExecutedCatalogue(uint256 indexed catalogueId, Catalogue);
    event EditedCatalogue(uint256 indexed catalogueId, Catalogue);

    LibDiamond.DiamondStorage s = LibDiamond.diamondStorage();


   
    function createCatalogue(LibDiamond.Catalogue calldata c) public returns (uint256) {
        
        require(ERC721(c.nftAddress).ownerOf(c.tokenId) == msg.sender, "NOt the owner");
        require(ERC721(c.nftAddress).isApprovedForAll(msg.sender, address(this)), "You don't have approval to sell this nft");
        
        require(c.price > (0.01 * 100), "Low price");
        require(c.deadline > block.timestamp, 'Deadline too short');

        // Assert signature
        require(SignUtils.isValid(
                SignUtils.constructMessageHash(
                    c.nftAddress,
                    c.tokenId,
                    c.price,
                    c.deadline,
                    c.creator
                ),
                c.signature,
                msg.sender
            ), "Invalid signsture");

        // append to Storage
        LibDiamond.Catalogue storage newCatalogue = s.catalogues[s.catalogueId];
        newCatalogue.nftAddress = c.nftAddress;
        newCatalogue.tokenId = c.tokenId;
        newCatalogue.price = c.price;
        newCatalogue.signature = c.signature;
        newCatalogue.deadline = uint88(c.deadline);
        newCatalogue.creator = msg.sender;
        newCatalogue.active = true;

        // Emit event
        emit CreatedCatalogue(s.catalogueId, newCatalogue);
        uint256 _catalogue = catalogueId;
        catalogueId++;
        return _catalogue;
    }

    function executeCatalogue(uint256 _catalogueId) public payable {
        require(_catalogueId <= s.catalogueId, "Catalogue does not exist");

        LibDiamond.Catalogue storage newCatalogue = s.catalogues[_catalogueId];

        require(newCatalogue.deadline > block.timestamp, "Expired catalogue");
        require(newCatalogue.active, "Inactive catalogue");
        require(newCatalogue.price == msg.value, "Inappriopriate price");

        // Update state
        newCatalogue.active = false;

        // transfer
        ERC721(newCatalogue.nftAddress).transferFrom(
            newCatalogue.creator,
            msg.sender,
            newCatalogue.tokenId
        );

        // transfer eth
        payable(newCatalogue.creator).transfer(newCatalogue.price);

        // Update storage
        emit ExecutedCatalogue(_catalogueId, newCatalogue);
    }

    function editCatalogue(
        uint256 _catalogueId,
        uint256 _newPrice,
        bool _active
    ) public {
        require(_catalogueId <= s.catalogueId, "Catalogue does not exist");

        LibDiamond.Catalogue storage newCatalogue = s.catalogues[_catalogueId];
    
        require(newCatalogue.creator == msg.sender, "You are not the owner");
        newCatalogue.price = _newPrice;
        newCatalogue.active = _active;
        emit EditedCatalogue(_catalogueId, newCatalogue);
    }

    
    function getCatalogue(
        uint256 _catalogueId
    ) public view returns (LibDiamond.Catalogue memory) {
        return catalogues[_catalogueId];
    }
}