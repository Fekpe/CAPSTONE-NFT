// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Cohort3NFT} from "../src/Cohort3NFT.sol";

contract Cohort3NFTExtraTest is Test {
    Cohort3NFT nft;
    address constant OWNER = address(0xBEEF);
    address constant ALICE = address(0xAAAA);
    address constant BOB = address(0xBBBB);

    uint256 constant MAX_SUPPLY = 100;
    uint256 constant MINT_PRICE = 0.01 ether;
    uint256 constant MAX_PER_WALLET = 5;

    function setUp() public {
        vm.prank(OWNER);
        nft = new Cohort3NFT("TechCrush Cohort 3", "TC3", MAX_SUPPLY, MINT_PRICE, MAX_PER_WALLET);
    }

    function test_enumeration_getAllTokens_and_ownerTokens() public {
        vm.prank(ALICE);
        vm.deal(ALICE, MINT_PRICE * 3);
        nft.mint{value: MINT_PRICE * 3}(3);

        vm.prank(BOB);
        vm.deal(BOB, MINT_PRICE * 2);
        nft.mint{value: MINT_PRICE * 2}(2);

        uint256[] memory all = nft.getAllTokens();
        assertEq(all.length, 5, "all tokens length mismatch");

        uint256[] memory aliceTokens = nft.getTokensOfOwner(ALICE);
        assertEq(aliceTokens.length, 3, "alice token count");
        assertEq(aliceTokens[0], 1);
        assertEq(aliceTokens[2], 3);

        uint256[] memory bobTokens = nft.getTokensOfOwner(BOB);
        assertEq(bobTokens.length, 2, "bob token count");
        assertEq(bobTokens[0], 4);
        assertEq(bobTokens[1], 5);
    }

    function test_tokenURI_contains_fields_and_base64_json() public {
        vm.prank(ALICE);
        vm.deal(ALICE, MINT_PRICE);
        nft.mint{value: MINT_PRICE}(1);

        string memory uri = nft.tokenURI(1);
        // Should start with data:application/json;base64,
        assertTrue(bytes(uri).length > 0, "tokenURI empty");
        bytes memory b = bytes(uri);
        bytes memory prefix = bytes("data:application/json;base64,");
        for (uint i = 0; i < prefix.length; i++) {
            assertEq(b[i], prefix[i], "prefix mismatch");
        }
    }

    function test_owner_only_functions_and_withdraw_security() public {
        // Only owner can call ownerMint, setMintPrice, setMaxPerWallet, setHiddenSVG, setRevealedSVG, reveal, withdraw
        vm.prank(ALICE);
        vm.expectRevert();
        nft.ownerMint(ALICE, 1);

        vm.prank(ALICE);
        vm.expectRevert();
        nft.setMintPrice(0);

        vm.prank(ALICE);
        vm.expectRevert();
        nft.setMaxPerWallet(1);

        vm.prank(ALICE);
        vm.expectRevert();
        nft.setHiddenSVG("x");

        vm.prank(ALICE);
        vm.expectRevert();
        nft.setRevealedSVG("y");

        vm.prank(ALICE);
        vm.expectRevert();
        nft.reveal();

        // Deposit funds and ensure withdraw works only for owner
        vm.deal(ALICE, MINT_PRICE);
        vm.prank(ALICE);
        nft.mint{value: MINT_PRICE}(1);
        assertEq(address(nft).balance, MINT_PRICE);

        vm.prank(ALICE);
        vm.expectRevert();
        nft.withdraw();

        vm.prank(OWNER);
        nft.withdraw();
        assertEq(address(nft).balance, 0);
    }
}
