// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {Cohort3NFT} from "../src/Cohort3NFT.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DeployCohort3NFT
 * @notice Deployment script for Cohort3NFT contract
 * @dev Run with: forge script script/DeployCohort3NFT.s.sol:DeployCohort3NFT --rpc-url <RPC_URL> --broadcast --verify
 */
contract DeployCohort3NFT is Script {
    // Configuration - Modify these values as needed
    string constant NAME = "TechCrush Cohort 3";
    string constant SYMBOL = "TC3";
    uint256 constant MAX_SUPPLY = 500;
    uint256 constant MINT_PRICE = 0.005 ether; // 0.01 ETH
    uint256 constant MAX_PER_WALLET = 3;

    function run() external returns (Cohort3NFT) {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Cohort3NFT contract...");
        console.log("Deployer address:", vm.addr(deployerPrivateKey));
        console.log("-----------------------------------");
        console.log("Configuration:");
        console.log("Name:", NAME);
        console.log("Symbol:", SYMBOL);
        console.log("Max Supply:", MAX_SUPPLY);
        console.log("Mint Price:", MINT_PRICE);
        console.log("Max Per Wallet:", MAX_PER_WALLET);
        console.log("-----------------------------------");

        // Deploy the contract
        Cohort3NFT nft = new Cohort3NFT(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            MINT_PRICE,
            MAX_PER_WALLET
        );

        console.log("Cohort3NFT deployed at:", address(nft));
        console.log("-----------------------------------");
        console.log("Contract Details:");
        console.log("Owner:", nft.owner());
        console.log("Max Supply:", nft.i_maxSupply());
        console.log("Mint Price:", nft.mintPrice());
        console.log("Max Per Wallet:", nft.maxPerWallet());
        console.log("Revealed:", nft.revealed());
        console.log("Total Minted:", nft.totalMinted());
        console.log("-----------------------------------");

        vm.stopBroadcast();

        return nft;
    }
}