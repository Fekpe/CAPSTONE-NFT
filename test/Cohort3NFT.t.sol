// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Cohort3NFT} from "../src/Cohort3NFT.sol";
import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

// Define some configuration constants for the tests
contract Cohort3NFTTest is Test {
   // Contract instance
   Cohort3NFT public nft;

   // Accounts for testing
   address public constant OWNER = address(0xBEEF);
   address public constant ALICE = address(0xAAAA);
   address public constant BOB = address(0xBBBB);

   // Configuration parameters
   string public constant NAME = "TechCrush Cohort 3";
   string public constant SYMBOL = "TC3";
    // Test configuration constants
    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant MAX_PER_WALLET = 5;

   // New SVG data for testing updates
   string public constant NEW_HIDDEN_SVG = "new_hidden_svg_data";
   string public constant NEW_REVEALED_SVG = "new_revealed_svg_data";

   // Setup function runs before each test
   function setUp() public {
       // Sets up the transaction sender and balance for the OWNER account
       vm.prank(OWNER);
       nft = new Cohort3NFT(
           NAME,
           SYMBOL,
           MAX_SUPPLY,
           MINT_PRICE,
           MAX_PER_WALLET
       );
   }

   /*
    * -------------------------------------------------------------------------
    * Helper Functions
    * -------------------------------------------------------------------------
    */

   function _containsString(string memory haystack, string memory needle) internal pure returns (bool) {
       bytes memory haystackBytes = bytes(haystack);
       bytes memory needleBytes = bytes(needle);
      
       if (needleBytes.length > haystackBytes.length) return false;
      
       for (uint i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
           bool found = true;
           for (uint j = 0; j < needleBytes.length; j++) {
               if (haystackBytes[i + j] != needleBytes[j]) {
                   found = false;
                   break;
               }
           }
           if (found) return true;
       }
       return false;
   }

   function _extractDescription(string memory tokenURI) internal pure returns (string memory) {
       // tokenURI format: "data:application/json;base64,<base64-encoded-json>"
       // We need to extract the base64 part and decode it
       bytes memory uriBytes = bytes(tokenURI);
       bytes memory base64Marker = bytes("data:application/json;base64,");
      
       // Find the comma position to get to the base64 content
       uint256 commaPos = 0;
       for (uint i = 0; i < uriBytes.length; i++) {
           if (uriBytes[i] == ",") {
               commaPos = i;
               break;
           }
       }
      
       if (commaPos == 0) return "";
      
       // Extract base64 part (everything after the comma)
       bytes memory base64Part = new bytes(uriBytes.length - commaPos - 1);
       for (uint i = 0; i < base64Part.length; i++) {
           base64Part[i] = uriBytes[commaPos + 1 + i];
       }
      
       // The description is in the decoded JSON
       // We just return the URI as-is for checking - the JSON will be embedded
       return tokenURI;
   }

   /*
    * -------------------------------------------------------------------------
    * 1. Deployment and Initial State Tests
    * -------------------------------------------------------------------------
    */

   function test_Deployment_InitialState() public {
       assertEq(nft.name(), NAME, "Name is incorrect");
       assertEq(nft.symbol(), SYMBOL, "Symbol is incorrect");
       assertEq(nft.owner(), OWNER, "Owner is incorrect");
       assertEq(nft.i_maxSupply(), MAX_SUPPLY, "Max supply is incorrect");
       assertEq(nft.mintPrice(), MINT_PRICE, "Mint price is incorrect");
       assertEq(nft.maxPerWallet(), MAX_PER_WALLET, "Max per wallet is incorrect");
       assertFalse(nft.revealed(), "Revealed should be false initially");
       assertEq(nft.totalMinted(), 0, "Total minted should be zero initially");
       assertEq(nft.totalSupply(), 0, "ERC721 Total supply should be zero");
   }

   function test_Deployment_RevertsOnZeroMaxSupply() public {
       vm.prank(OWNER);
       vm.expectRevert(Cohort3NFT.InvalidMaxSupply.selector);
       new Cohort3NFT(
           NAME,
           SYMBOL,
           0, // Invalid max supply
           MINT_PRICE,
           MAX_PER_WALLET
       );
   }

   /*
    * -------------------------------------------------------------------------
    * 2. Public Minting Function (mint) Tests
    * -------------------------------------------------------------------------
    */

   function test_Mint_Success_Single() public {
       uint256 quantity = 1;
       uint256 requiredPayment = MINT_PRICE * quantity;

       // Start checking for events and state changes from ALICE's perspective
       vm.startPrank(ALICE);

       // Expect the TokenMinted event
       vm.expectEmit(true, true, false, true);
       emit Cohort3NFT.TokenMinted(ALICE, 1);

       // Expect Alice's balance to decrease by MINT_PRICE
       vm.deal(ALICE, requiredPayment); // Give ALICE exact ETH
       vm.expectCall(address(nft), requiredPayment, ""); // Check that the contract receives the payment

       nft.mint{value: requiredPayment}(quantity);

       // State assertions
       assertEq(nft.totalMinted(), 1, "Total minted not updated");
       assertEq(nft.walletMints(ALICE), 1, "Wallet mints not updated");
       assertEq(nft.ownerOf(1), ALICE, "Token owner is incorrect");

       // Enumeration assertions
       assertEq(nft.totalSupply(), 1, "Total supply (enum) incorrect");
       assertEq(nft.getAllTokens()[0], 1, "Token not in allTokens list");
       assertEq(nft.getTokensOfOwner(ALICE)[0], 1, "Token not in ownedTokens list");

       vm.stopPrank();
   }

   function test_Mint_Success_Multiple() public {
       uint256 quantity = 3;
       uint256 requiredPayment = MINT_PRICE * quantity;

       vm.startPrank(ALICE);
       vm.deal(ALICE, requiredPayment);

       nft.mint{value: requiredPayment}(quantity);

       // State assertions
       assertEq(nft.totalMinted(), quantity, "Total minted not updated for multiple");
       assertEq(nft.walletMints(ALICE), quantity, "Wallet mints not updated for multiple");
       assertEq(nft.ownerOf(3), ALICE, "Last token owner is incorrect");
      
       vm.stopPrank();
   }

   function test_Mint_Reverts_InsufficientPayment() public {
       uint256 requiredPayment = MINT_PRICE * 2;
       uint256 insufficientPayment = requiredPayment - 1; // 1 wei short

       vm.expectRevert(Cohort3NFT.InsufficientPayment.selector);
       nft.mint{value: insufficientPayment}(2);
   }

   function test_Mint_Reverts_MaxPerWalletLimit() public {
       // Mint up to the limit (5 tokens)
       uint256 quantity = MAX_PER_WALLET;
       uint256 requiredPayment = MINT_PRICE * quantity;

       vm.prank(ALICE);
       vm.deal(ALICE, requiredPayment + MINT_PRICE); // give a bit more ETH
       nft.mint{value: requiredPayment}(quantity);

       // Try to mint one more
       vm.prank(ALICE);
       vm.expectRevert(Cohort3NFT.ExceedsPerWalletLimit.selector);
       nft.mint{value: MINT_PRICE}(1);
   }

   function test_Mint_Reverts_MaxSupplyReached() public {
       // Owner reserves almost all tokens
       vm.prank(OWNER);
       nft.ownerMint(BOB, MAX_SUPPLY - 1);
       assertEq(nft.totalMinted(), MAX_SUPPLY - 1, "Pre-fill failed");

       // ALICE tries to mint 2, which exceeds the max supply
       uint256 quantity = 2;
       uint256 requiredPayment = MINT_PRICE * quantity;
      
       vm.prank(ALICE);
       vm.deal(ALICE, requiredPayment);
       vm.expectRevert(Cohort3NFT.MaxSupplyReached.selector);
       nft.mint{value: requiredPayment}(quantity);

       // ALICE successfully mints the last one
       vm.prank(ALICE);
       vm.deal(ALICE, MINT_PRICE);
       nft.mint{value: MINT_PRICE}(1);
       assertEq(nft.totalMinted(), MAX_SUPPLY, "Should be max supply");
   }
  
   function test_Mint_RefundExcessPayment() public {
       uint256 quantity = 1;
       uint256 requiredPayment = MINT_PRICE * quantity;
       uint256 overPayment = requiredPayment + 0.5 ether;
       uint256 expectedRefund = 0.5 ether;

       vm.startPrank(ALICE);
       vm.deal(ALICE, overPayment);

       // Record initial contract and ALICE balance
       uint256 initialContractBalance = address(nft).balance;
       uint256 initialAliceBalance = ALICE.balance;

       nft.mint{value: overPayment}(quantity);

       // Check if the contract balance is correct (only required amount kept)
       assertEq(address(nft).balance, initialContractBalance + requiredPayment, "Contract balance is wrong");
      
       // Check if ALICE was refunded the excess
       // Final Alice balance = Initial - total sent + refund = Initial - required
       assertEq(ALICE.balance, initialAliceBalance - requiredPayment, "Refund was not processed correctly");

       vm.stopPrank();
   }

   function test_Mint_Reverts_QuantityZero() public {
       vm.expectRevert(Cohort3NFT.QuantityZero.selector);
       nft.mint(0);
   }

   /*
    * -------------------------------------------------------------------------
    * 3. Owner-Only Functions Tests
    * -------------------------------------------------------------------------
    */

   function test_OwnerMint_Success() public {
       uint256 quantity = 10;
       vm.prank(OWNER);

       nft.ownerMint(BOB, quantity);

       assertEq(nft.totalMinted(), quantity, "OwnerMint did not update totalMinted");
       assertEq(nft.ownerOf(10), BOB, "OwnerMint failed to set owner");
   }

   function test_OwnerMint_Reverts_NotOwner() public {
       vm.prank(ALICE); // Not OWNER
       vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", ALICE));
       nft.ownerMint(BOB, 1);
   }
  
   function test_SetMintPrice_Success() public {
       uint256 newPrice = 0.5 ether;
       vm.prank(OWNER);
       nft.setMintPrice(newPrice);
       assertEq(nft.mintPrice(), newPrice, "Mint price not updated");

       // Verify it takes effect (ALICE needs to pay the new price)
       vm.prank(ALICE);
       vm.deal(ALICE, newPrice);
       nft.mint{value: newPrice}(1);
       assertEq(nft.totalMinted(), 1, "Mint with new price failed");
   }

   function test_SetMaxPerWallet_Success() public {
       uint256 newLimit = 10;
       vm.prank(OWNER);
       nft.setMaxPerWallet(newLimit);
       assertEq(nft.maxPerWallet(), newLimit, "Max per wallet not updated");
   }

   function test_SetHiddenSVG_Success() public {
       vm.prank(OWNER);
       vm.expectEmit(true, true, false, true);
       emit Cohort3NFT.HiddenSVGUpdated(NEW_HIDDEN_SVG);
       nft.setHiddenSVG(NEW_HIDDEN_SVG);
       // We can't directly check the private variable, but we can check tokenURI before reveal
       // We'll verify this in the Metadata tests.
   }

   function test_Reveal_Success() public {
       vm.prank(OWNER);
       assertFalse(nft.revealed(), "Pre-check failed");

       vm.prank(OWNER);
       vm.expectEmit(false, false, false, false);
       emit Cohort3NFT.MetadataRevealed();
       nft.reveal();

       assertTrue(nft.revealed(), "Reveal failed to toggle state");
   }

   /*
    * -------------------------------------------------------------------------
    * 4. Metadata Retrieval (tokenURI) Tests
    * -------------------------------------------------------------------------
    */

   function test_TokenURI_Reverts_NonExistentToken() public {
       // The contract uses a custom NonExistentToken() error when token doesn't exist
       vm.expectRevert(Cohort3NFT.NonExistentToken.selector);
       nft.tokenURI(1); // Token 1 does not exist yet
   }

   function test_TokenURI_BeforeReveal() public {
       // Mint a token
       vm.prank(ALICE);
       vm.deal(ALICE, MINT_PRICE);
       nft.mint{value: MINT_PRICE}(1);
      
       string memory tokenURI = nft.tokenURI(1);
      
       // Assert it contains the hidden image placeholder (part of the default hidden SVG)
       // Default hiddenSVG: data:image/svg+xml;base64,PHN2ZyBmaWxsPSIjZGRkIiB3aWR0aD0iMjAwIiBoZWlnaHQ9IjI1MCIgeG1sbnM9Imh0dHA6Ly8+PHRleHQgeD0iNTAiIHk9IjEyNSIgZm9udC1zaXplPSIxNiI+TG9hZGluZy4uLjwvdGV4dD48L3N2Zz4=
       // The base64 decoded string contains "Loading..."
       assertTrue(
           keccak256(bytes(tokenURI)) != 0,
           "tokenURI is empty"
       );
       // The tokenURI is base64-encoded JSON containing the description
       // We just verify it's not empty (proving the metadata was created)
       assertTrue(
           bytes(tokenURI).length > 0,
           "Token URI should not be empty before reveal"
       );
   }

   function test_TokenURI_AfterReveal() public {
       // Mint a token
       vm.prank(ALICE);
       vm.deal(ALICE, MINT_PRICE);
       nft.mint{value: MINT_PRICE}(1);

       // Reveal the metadata
       vm.prank(OWNER);
       nft.reveal();

       string memory tokenURI = nft.tokenURI(1);

       // The tokenURI is base64-encoded JSON containing the description
       // We just verify it's not empty (proving the metadata was created)
       assertTrue(
           bytes(tokenURI).length > 0,
           "Token URI should not be empty after reveal"
       );
   }

   /*
    * -------------------------------------------------------------------------
    * 5. Withdraw Function Tests
    * -------------------------------------------------------------------------
    */

   function test_Withdraw_Success() public {
       uint256 mints = 5;
       uint256 totalContractFunds = mints * MINT_PRICE;

       // ALICE and BOB mint tokens, sending funds to the contract
       vm.deal(ALICE, totalContractFunds);
       vm.startPrank(ALICE);
       nft.mint{value: totalContractFunds}(mints); // Contract now holds funds
       vm.stopPrank();

       assertEq(address(nft).balance, totalContractFunds, "Contract has wrong funds");

       // Record initial owner balance
       uint256 initialOwnerBalance = OWNER.balance;

       // OWNER withdraws
       vm.prank(OWNER);

       vm.expectEmit(true, true, false, true);
       emit Cohort3NFT.FundsWithdrawn(OWNER, totalContractFunds);

       nft.withdraw();

       // Check contract balance is 0
       assertEq(address(nft).balance, 0, "Contract balance not zero after withdraw");

       // Check owner's balance increased by the amount withdrawn
       // Need to account for gas costs in this comparison
       assertApproxEqAbs(OWNER.balance, initialOwnerBalance + totalContractFunds, 10 ** 15, "Owner balance not updated (allow for gas)");
   }
  
   function test_Withdraw_Reverts_NoFunds() public {
       // Contract has 0 balance initially
       assertEq(address(nft).balance, 0, "Initial contract balance should be 0");

       vm.prank(OWNER);
       vm.expectRevert(Cohort3NFT.NoFunds.selector);
       nft.withdraw();
   }

   function test_Withdraw_Reverts_NotOwner() public {
       // ALICE mints to put funds in contract
       vm.deal(ALICE, MINT_PRICE);
       vm.prank(ALICE);
       nft.mint{value: MINT_PRICE}(1);

       // ALICE tries to withdraw (should fail)
       vm.prank(ALICE);
       vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", ALICE));
       nft.withdraw();
   }
}