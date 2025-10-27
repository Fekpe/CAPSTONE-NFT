// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Base64} from "../lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {Strings} from "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title Cohort3NFT
 * @notice Beginner-friendly ERC-721 NFT contract with enumeration and a reveal mechanism.
 * @dev Anyone can mint within set limits. Metadata (SVG) is on-chain. Owner can set hidden & revealed SVGs and toggle reveal.
 */
contract Cohort3NFT is ERC721, Ownable {
    using Strings for uint256;

    // Custom errors
    error MaxSupplyReached();
    error ExceedsPerWalletLimit();
    error InsufficientPayment();
    error ZeroAddress();
    error NoFunds();
    error NonExistentToken();
    error InvalidMaxSupply();
    error WithdrawFailed();
    error QuantityZero();
    
    // State variables
    uint256 public immutable i_maxSupply;
    uint256 public totalMinted;
    uint256 public mintPrice;
    uint256 public maxPerWallet;

    mapping(address => uint256) public walletMints;

    // enumeration helpers (simple arrays; cheaper than OZ Enumerable for small projects)
    uint256[] private _allTokens;
    mapping(address => uint256[]) private _ownedTokens;

    // reveal / metadata
    bool public revealed;
    string private hiddenSVG;    // data:image/svg+xml;base64,...
    string private revealedSVG;  // data:image/svg+xml;base64,...

    // Events
    event TokenMinted(address indexed minter, uint256 indexed tokenId);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    event MetadataRevealed();
    event HiddenSVGUpdated(string newHiddenSVG);
    event RevealedSVGUpdated(string newRevealedSVG);

    // Settting our Constructor
    /**
     * @param _name collection name
     * @param _symbol collection symbol
     * @param _maxSupply total cap
     * @param _mintPrice initial mint price (wei)
     * @param _maxPerWallet per-wallet cap
     */
    constructor(string memory _name, string memory _symbol, uint256 _maxSupply, uint256 _mintPrice, uint256 _maxPerWallet) ERC721(_name, _symbol) {
        if (_maxSupply == 0) revert InvalidMaxSupply();
        i_maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        maxPerWallet = _maxPerWallet;

        // sensible defaults (can be changed by owner before reveal)
        hiddenSVG = "data:image/svg+xml;base64,PHN2ZyBmaWxsPSIjZGRkIiB3aWR0aD0iMjAwIiBoZWlnaHQ9IjI1MCIgeG1sbnM9Imh0dHA6Ly8+PHRleHQgeD0iNTAiIHk9IjEyNSIgZm9udC1zaXplPSIxNiI+TG9hZGluZy4uLjwvdGV4dD48L3N2Zz4=";
        revealedSVG = "data:image/svg+xml;base64,PHN2ZyB2aWV3Qm94PSIwIDAgMjAwIDI1MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjI1MCIgZmlsbD0iI2ZmZiIvPjx0ZXh0IHg9IjUwIiB5PSIxMjUiIGZvbnQtc2l6ZT0iMTYiIGZpbGw9ImJsYWNrIj5UZWNocnVzaCBDb2hvcnQgMzwvdGV4dD48L3N2Zz4=";
        revealed = false;
    }

    // Public minting function
    /** 
     * @notice Allows anyone to mint NFTs by paying the correct amount. 
     * @param quantity Number of NFTs to mint. 
     */
    function mint(uint256 quantity) external payable {
        if (quantity == 0) revert QuantityZero();

        uint256 newTotal = totalMinted + quantity;
        if (newTotal > i_maxSupply) revert MaxSupplyReached();

        uint256 mintedByWallet = walletMints[msg.sender];
        if (mintedByWallet + quantity > maxPerWallet) revert ExceedsPerWalletLimit();

        uint256 required = mintPrice * quantity;
        if (msg.value < required) revert InsufficientPayment();

        // mint loop
        for (uint256 i = 0; i < quantity; ) {
            uint256 tokenId = totalMinted + 1;
            totalMinted = tokenId;

            _safeMint(msg.sender, tokenId);
            emit TokenMinted(msg.sender, tokenId);

            // enumeration bookkeeping
            _allTokens.push(tokenId);
            _ownedTokens[msg.sender].push(tokenId);

            unchecked { 
                ++i; 
            }
        }

        walletMints[msg.sender] = mintedByWallet + quantity;

        // refund excess
        if (msg.value > required) {
            payable(msg.sender).transfer(msg.value - required);
        }
    }

    /**
     * @notice Owner can mint tokens to an address without payment (reserve).
     */
    function ownerMint(address to, uint256 quantity) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();

        uint256 newTotal = totalMinted + quantity;
        if (newTotal > i_maxSupply) revert MaxSupplyReached();

        for (uint256 i = 0; i < quantity; ) {
            uint256 tokenId = totalMinted + 1;
            totalMinted = tokenId;

            _safeMint(to, tokenId);
            emit TokenMinted(to, tokenId);

            _allTokens.push(tokenId);
            _ownedTokens[to].push(tokenId);

            unchecked { 
                ++i; 
            }
        }
    }

    // set mint price in wei
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    // set new max per wallet
    function setMaxPerWallet(uint256 newLimit) external onlyOwner {
        maxPerWallet = newLimit;
    }

    // set the hidden SVG (owner can update before/after reveal if needed)
    function setHiddenSVG(string calldata svgDataURI) external onlyOwner {
        hiddenSVG = svgDataURI;
        emit HiddenSVGUpdated(svgDataURI);
    }

    // set the revealed SVG (owner can update before reveal)
    function setRevealedSVG(string calldata svgDataURI) external onlyOwner {
        revealedSVG = svgDataURI;
        emit RevealedSVGUpdated(svgDataURI);
    }

    // onlyOwner to flip reveal to true
    function reveal() external onlyOwner {
        revealed = true;
        emit MetadataRevealed();
    }

    // Withdraws all ETH from the contract to the owner’s wallet. 
    function withdraw() external onlyOwner { 
        uint256 balance = address(this).balance; 
        if (balance == 0) revert NoFunds(); 
        (bool success, ) = payable(owner()).call{value: balance}(""); 
        if (!success) revert WithdrawFailed(); 
        emit FundsWithdrawn(owner(), balance); 
    }

    // Metadata functions
    /**
     * @notice Returns on-chain metadata (Base64 JSON) with hidden or revealed SVG
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert NonExistentToken();

        string memory image = revealed ? revealedSVG : hiddenSVG;
        string memory desc = revealed
            ? "Awarded to verified members of TechCrush Cohort 3."
            : "Hidden metadata until reveal.";

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name":"', name(), ' #',
                        tokenId.toString(),
                        '", "description":"', desc,
                        '", "image":"', image, '"}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    // Enumeration functions
    function totalSupply() external view returns (uint256) {
        return totalMinted;
    }

    function getAllTokens() external view returns (uint256[] memory) {
        return _allTokens;
    }

    function getTokensOfOwner(address ownerAddr) external view returns (uint256[] memory) {
        return _ownedTokens[ownerAddr];
    }
}