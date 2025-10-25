// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts@5.3.0/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts@5.3.0/token/ERC721/ERC721.sol";
import {ERC721Pausable} from "@openzeppelin/contracts@5.3.0/token/ERC721/extensions/ERC721Pausable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts@5.3.0/token/ERC721/extensions/ERC721URIStorage.sol";

contract AccessControlContract is ERC721, ERC721URIStorage, ERC721Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE"); // 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a
    uint256 private _nextTokenId;

    constructor() ERC721("GreatNFT", "GTF") {
        address mainAddress = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, mainAddress); // 0x0000000000000000000000000000000000000000000000000000000000000000
        _grantRole(PAUSER_ROLE, mainAddress);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(address to, string memory uri)
        public
        returns (uint256)
    {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }

    // Overrides obligatorios
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}