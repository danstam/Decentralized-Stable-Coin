// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

import {StdCheats} from "forge-std/StdCheats.sol";

contract TestDecentralizedStableCoin is Test {
    DecentralizedStableCoin public stableCoin;
    uint256 constant MINT_AMOUNT = 50 ether;
    uint256 constant BURN_AMOUNT = 50 ether;

    function setUp() public {
        stableCoin = new DecentralizedStableCoin();
    }

    function testSetUpIsSuccesful() public view {
        assert(address(stableCoin) != address(0));
    }

    //////////////
    //MINT TEST//
    ////////////

    function testMint() public {
        vm.prank(stableCoin.owner());
        stableCoin.mint(address(this), MINT_AMOUNT);
        uint256 finalBalance = stableCoin.balanceOf(address(this));
        assert(MINT_AMOUNT == finalBalance);
    }

    function testMintByNonOwner() public {
        address USER = makeAddr("user");
        vm.prank(USER);
        vm.expectRevert();
        stableCoin.mint(address(USER), MINT_AMOUNT);
    }

    function testMustMintMoreThanZero() public {
        vm.prank(stableCoin.owner());
        vm.expectRevert();
        stableCoin.mint(address(this), 0);
    }

    function testWillNotMintoToZeroAddress() public {
        vm.prank(stableCoin.owner());
        vm.expectRevert();
        stableCoin.mint(address(0), MINT_AMOUNT);
    }

    //////////////
    //BURN TEST//
    ////////////

    function testBurn() public {
        vm.prank(stableCoin.owner());
        stableCoin.mint(address(this), MINT_AMOUNT);
        uint256 initialBalance = stableCoin.balanceOf(address(this));
        console.log("Initial balance: ", initialBalance);
        vm.prank(stableCoin.owner());
        stableCoin.burn(BURN_AMOUNT);
        uint256 finalBalance = stableCoin.balanceOf(address(this));
        console.log("Final balance: ", finalBalance);
        assert(initialBalance - BURN_AMOUNT == finalBalance);
    }

    function testBurnByNonOwner() public {
        address USER = makeAddr("user");
        vm.prank(USER);
        vm.expectRevert();
        stableCoin.burn(BURN_AMOUNT);
    }

    function testMustBurnMoreThanZero() public {
        vm.prank(stableCoin.owner());
        stableCoin.mint(address(this), MINT_AMOUNT);
        vm.expectRevert();
        stableCoin.burn(0);
    }

    function testBurnAmountMustBeLessThanBalance() public {
        vm.prank(stableCoin.owner());
        uint256 amountToBurn = MINT_AMOUNT + 1;
        vm.expectRevert();
        stableCoin.burn(amountToBurn);
    }
}
